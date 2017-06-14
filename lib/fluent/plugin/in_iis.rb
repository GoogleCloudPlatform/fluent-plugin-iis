# Copyright 2017 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fluent/input'
require 'fluent/plugin_helper/timer'

require_relative 'log_directives'
require_relative 'log_state'
require_relative 'position'

module Fluent
  # A fluentd input plugin for reading W3C IIS logs.
  class IISInput < Input
    Fluent::Plugin.register_input('iis', self)

    helpers :timer

    desc 'The path(s) to read from.  Accepts comma separated paths and wild cards \'*\'.'
    config_param :path, :string, default: 'C:/inetpub/logs/LogFiles/W3SVC*/**/*.log'

    desc 'The tag to emit the entries as.'
    config_param :tag, :string, default: 'iis'

    desc 'A file to keep track of the read positions in logs.'
    config_param :pos_file, :string, default: nil

    desc 'How often the list of watched logs is refreshed in seconds.'
    config_param :refresh_logs_list, :integer, default: 60

    desc 'How often the position file is written to in seconds.'
    config_param :write_position_file, :integer, default: 60

    desc 'How often log entries should be read for each file in seconds.'
    config_param :read_log_entires, :integer, default: 60

    desc 'The maximum number of lines to read from one file at a time.'
    config_param :read_line_limit, :integer, default: 1000

    desc 'If log entries should be processed. Associating each directive with its entry in each log.'
    config_param :process_logs, :bool, default: false


    def initialize()
      super
      # A map from string file path to LogState containing all the currently watched files.
      @watched_files = {}
      # The event timer to refresh the list of watched files.
      @watcher_refresh_timer = nil
      # The event timer to write out the position file.
      @write_pos_file_timer = nil
      # The position file object.
      @pos = nil
    end

    def configure(conf)
      super
      @pos = PositionFile.new(@pos_file) if @pos_file != nil
    end

    def start()
      super
      # Start the timers to watch files and update the position file.
      @watcher_refresh_timer = timer_execute(:iis_refresh_watchers, @refresh_logs_list, &method(:refresh_watchers))
      @write_pos_file_timer = timer_execute(:iis_write_pos_file, @write_position_file, &method(:write_pos_file)) if @pos != nil
    end

    def shutdown()
      super
      # Stop all active watches.
      stop_watches(@watched_files.keys)

      # Stop the timers if they are running.
      @watcher_refresh_timer.detach if @watcher_refresh_timer.attached?
      @write_pos_file_timer.detach if @write_pos_file_timer != nil && @write_pos_file_timer.attached?

      # Write out the final position file.
      @pos.write_to_file() if @pos != nil
    end

  private
    # Refresh the list of currently watched files. Adding unwatched files and removing files
    # that no longer exist.
    def refresh_watchers()
      paths = []

      # A list of all file paths the user passed in.
      unresolved_paths = @path.split(',')
      unresolved_paths = unresolved_paths.size == 0 ? @path : unresolved_paths

      # Glob all file paths and keep all readable files.
      for unresolved_path in unresolved_paths
        paths += Dir.glob(unresolved_path.strip).select do |resource|
          File.file?(resource) && File.readable?(resource)
        end
      end

      watched = @watched_files.keys

      # Files we are not yet watching.
      new_files = paths - watched

      # Files we are watching that no longer exist.
      dead_files = watched - paths

      start_watches(new_files)
      stop_watches(dead_files, true)
    end

    # Write an updated position file if any positions have changed.
    def write_pos_file()
      last_update = File.exist?(@pos.pos_file) ? File.mtime(@pos.pos_file) : Time.at(0)
      for state in @watched_files.values
        if last_update < state.last_emit
          @pos.write_to_file()
          break
        end
      end
    end

    # Start watching file paths.
    # Params:
    # +paths+:: An array of string paths.
    def start_watches(paths)
      for path in paths
        # Get or create a Position object for the file path.
        pos_file = @pos != nil ? @pos.get_position(path) : Position.new(path)
        # Create a LogState to track the log.
        log_state = LogState.new(pos_file, method(:emit_lines))
        # Start a timer to check for changes in the log and emit new lines.
        log_state.timer = timer_execute(:iis_file_watchers, @read_log_entires, repeat: false, &log_state.method(:emit_lines))
        @watched_files[path] = log_state
      end
    end

    # Stop watching file paths.
    # Params:
    # +paths+:: An array of string paths.
    # +delete_pos+:: If the associated position in the position file should be deleted.
    #   Defaults to false.
    def stop_watches(paths, delete_pos = false)
      for path in paths
        log_state = @watched_files.delete(path)
        log_state.timer.detach if log_state.timer.attached?
        @pos.remove_position(path) if delete_pos && @pos != nil
      end
    end

    # Emit records (lines) for a given LogState.
    # Params:
    # +log_state+:: The LogState to emit records for.
    def emit_lines(log_state)
      begin
        # If the file doesn't exist do not emit lines.  The watch will be cleaned up on the next refresh.
        if !File.exist?(log_state.pos_file.path)
          return
        end

        # If there are no unread lines from the last read and the file has not been modified
        # do not emit lines.
        if !log_state.unread_lines && File.mtime(log_state.pos_file.path) < log_state.last_emit
          return
        end

        file = File.open(log_state.pos_file.path)

        # Read in the last directives if they exist.
        if log_state.pos_file.last_directives_pos >= 0
          update_directives(file, log_state)
        end

        # Seek to the last read position.
        if log_state.pos_file.last_read_pos >= 0
          file.seek(log_state.pos_file.last_read_pos)
        end

        # Create an event stream to write records to.
        event_stream = MultiEventStream.new()

        # The last start position of directives.
        last_directives_pos = nil

        # Keep track of log directives as they are read in.
        # We cannot emit them as we read them as we need the date
        # from the Date directive to properly date all the directives.
        log_directives = []

        for _ in 0...@read_line_limit
          starting_pos = file.pos
          begin
            line = file.readline.strip
          rescue EOFError
            log_state.unread_lines = false
            break
          end

          if LogDirectives.is_directive(line)
            # If this is a new set of directives record needed info.
            if log_directives.empty?
              # Save the directive start position to record later.
              last_directives_pos = starting_pos
              # Clear out any old directives to ensure no stale data.
              log_state.log_directives = LogDirectives.new()
            end
            log_state.log_directives.process_info(line)
            log_directives.push(line)
          else
            # If we have finished reading directives write out the info.
            if !log_directives.empty?
              for directive in log_directives
                record = create_record(directive, path, log_state, false)
                event_stream.add(Engine.now, record)
              end
            end

            log_directives = []
            record = create_record(line, file.path, log_state, @process_logs)
            event_stream.add(Engine.now, record)
          end
        end

        # Update info in the LogState, close the file and emit the stream.
        log_state.pos_file.last_read_pos = file.pos
        log_state.pos_file.last_directives_pos = last_directives_pos if last_directives_pos != nil
        file.close()
        log_state.last_emit = Time.now
        router.emit_stream(@tag, event_stream)
      ensure
        log_state.timer = timer_execute(:iis_file_watchers, @read_log_entires, repeat: false, &log_state.method(:emit_lines))
      end
    end

    # Update a LogState's LogDirectives from a file.
    # Params:
    # +file+:: A file open for reading.
    # +log_state+:: The LogState associated with the file.
    def update_directives(file, log_state)
      # Clear out any old directives to ensure no stale data.
      log_state.log_directives = LogDirectives.new()
      file.seek(log_state.pos_file.last_directives_pos)

      # There should not be more than 8-10 directives but allow more to be safe.
      for _ in 1..20
        begin
          line = file.readline
          if LogDirectives.is_directive(line)
            log_state.log_directives.process_info(line)
          else
            return
          end
        rescue EOFError
          break
        end
      end
    end

    # Create a recored to be emitted.
    # Params:
    # +line+:: The line of text to emit.
    # +path+:: The path of the file the line was from.
    # +log_state+:: The LogState associated with the file path.
    # +process_fields+:: True if the fields should be processed.
    def create_record(line, path, log_state, process_fields)
      directives = {}

      # If we have directive information about fields in the logs parse it.
      if log_state.log_directives.fields != nil
        directives = Hash[log_state.log_directives.fields.zip(line.split(" "))]
      end

      if process_fields && log_state.log_directives.fields != nil
        record = directives
      elsif
        record = {'message' => line }
      end

      # Add information about where the log entry came from.
      record['log-path'] = path
      # Attempt to get a timestamp from the fields and/or directives.
      timestamp = get_timestamp(directives['date'], directives['time'], log_state.log_directives.date)
      record['timestamp'] = timestamp if timestamp != nil
      return record
    end

    # Get a timestamp in the format:
    #  {'seconds' => int, 'nanos' => int}
    # Will attempt to create the timestamp with the date and time but will fall back to
    # the date_time if needed.
    # Params:
    # +date+:: A date as a string.  Can be nil.
    # +time+:: A date as a string.  Can be nil.
    # +date_time+:: A date and time as a string.  Can be nil.
    def get_timestamp(date, time, date_time)
      timestamep_str = nil
      if date != nil && time != nil
        timestamep_str = "#{date} #{time}"
      elsif time != nil && date_time != nil
        parts = date_time.split(" ")
        date = parts.size == 0 ? date : parts.first
        timestamep_str = "#{date} #{time}"
      elsif date_time != nil
        timestamep_str = date_time
      else
        return nil
      end

      begin
        time = Time.parse(timestamep_str)
        return {'seconds' => time.tv_sec, 'nanos' => time.tv_nsec}
      rescue
        return nil
      end
    end

  end
end
