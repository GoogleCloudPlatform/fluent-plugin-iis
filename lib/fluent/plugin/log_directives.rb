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

# Directive information for a W3C log.
class LogDirectives
  attr_reader :software
  attr_reader :version
  attr_reader :date
  attr_reader :fields
  attr_reader :start_date
  attr_reader :end_date
  attr_reader :remark

  # Create a new LogDirectives.
  def initialize()
    @software = @version = @date = nil
    @start_date = @end_date = @remark = nil

    # An array of fields (string) or nil if none are found.
    @fields = nil
  end

  # Check if a log line is a directive.
  # Params:
  # +line+:: The log line to check.
  def self.is_directive(line)
    return line.start_with?("#")
  end

  # Process and store directive information.
  # Params:
  # +line+:: The log line to process.
  def process_info(line)
    if line.start_with?("#Software: ")
      @software = get_value(line)
    elsif line.start_with?("#Version: ")
      @version = get_value(line)
    elsif line.start_with?("#Date: ")
      @date = get_value(line)
    elsif line.start_with?("#Fields: ")
      @fields = line.strip.split(" ")[1..-1] if line != nil
    elsif line.start_with?("#Start-Date: ")
      @start_date = get_value(line)
    elsif line.start_with?("#End-Date: ")
      @end_date = get_value(line)
    elsif line.start_with?("#Remark: ")
      @remark = get_value(line)
    else
      $log.info "Unknown log information #{line}"
    end
  end

  private
    def get_value(line)
      if line == nil
        return nil
      end

      parts = line.strip.split(" ", 2)
      if parts.size < 2
        return nil
      end

      return parts[1]
    end
end
