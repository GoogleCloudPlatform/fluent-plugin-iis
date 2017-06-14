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

# Manages a position file containing position information of log files.
class PositionFile
  attr_reader :pos_file
  attr_reader :pos

  # Create a new PositionFile.
  # Params:
  # +pos_file+:: The path of the file position file.  The file will be created if it does not exist.
  def initialize(pos_file)
    # The path to the position file.
    @pos_file = pos_file

    # A map from path (string) of the file position information is being stored to
    # the Position object.
    @pos = {}

    # If the file exists read in the position information.
    if File.exist?(@pos_file)
      File.open(@pos_file) do |file|
        file.each_line do |line|
          pos = Position.from_string(line)
          @pos[pos.path] = pos
        end
      end
    end
  end

  # Get a Position for the given path. If none exist one will be created.
  # Params:
  # +path+:: The path of the Position information.
  def get_position(path)
    if @pos[path] == nil
      @pos[path] = Position.new(path)
    end
    return @pos[path]
  end

  # Remove position information for a path and return the Position or nil of none existed.
  # Params:
  # +path+:: The path of the Position information.
  def remove_position(path)
    return @pos.delete(path)
  end

  # Write the position information to the position file.  The file will be overwritten
  # with the current data.
  def write_to_file()
    File.open(@pos_file, 'w') do |file|
      @pos.each do |key, value|
        file.puts "#{value}\n"
      end
    end
  end
end

# Position information for a file.
class Position
  attr_reader :path
  attr_accessor :last_directives_pos
  attr_accessor :last_read_pos

  # Create a new Position.
  # Params:
  # +path+:: The path of the file.
  # +last_directives_pos+:: Start position of the last set of directives. Defaults to -1.
  # +last_read_pos+:: The last read position. Defaults to -1.
  def initialize(path, last_directives_pos = -1, last_read_pos = -1)
    @path = path
    @last_directives_pos = last_directives_pos
    @last_read_pos = last_read_pos
  end

  # Create a new Position from a string. The string should have been created
  # with to_s.
  def self.from_string(str)
    parts = str.strip.split(" ")
    if parts.length != 3
      raise ArgumentError.new("Invalid position string. #{str}")
    end
    return Position.new(parts[0], Integer(parts[1]), Integer(parts[2]))
  end

  def to_s()
    return "#{@path} #{@last_directives_pos} #{@last_read_pos}"
  end
end
