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

require_relative 'log_directives'

# Class to encapsulate the state of a log.
class LogState
  attr_accessor :log_directives
  attr_accessor :pos_file
  attr_accessor :timer
  attr_accessor :emit_lines_func
  attr_accessor :last_emit
  attr_accessor :unread_lines

  # Create a new LogState.
  # Params:
  # +pos_file+:: The position file object.
  # +emit_lines_func+:: A function that will take a LogState and emit lines of a log.
  def initialize(pos_file, emit_lines_func)
    # The position file object.
    @pos_file = pos_file

    # A function that will take a LogState and emit lines of a log.
    @emit_lines_func = emit_lines_func

    # The log's current directives.
    @log_directives = LogDirectives.new()

    # The timer to check for new lines in the logs and emit them.
    @timer = nil

    # The last time lines were emitted for the log.
    @last_emit = Time.at(0)

    # True if the log contains unread lines from the last read.
    @unread_lines = true
  end

  def emit_lines()
    @emit_lines_func.call(self)
  end
end
