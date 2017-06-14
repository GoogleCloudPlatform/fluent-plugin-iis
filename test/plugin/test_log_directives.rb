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

require 'fluent/plugin/log_directives'
require 'test/unit'

class LogDirectivesTest < Test::Unit::TestCase
  @@directives =
    "#Software: Some software thing\n"\
    "#Version: 1.0\n"\
    "#Date: 2000-01-01 12:00:00\n"\
    "#Fields: date time ip method\n"\
    "#Start-Date: 2001-01-01 12:00:00\n"\
    "#End-Date: 2002-01-01 12:00:00\n"\
    "#Remark: Some reamrk.\n"\

  def test_log_directives
    directives = LogDirectives.new()
    assert_nil(directives.software)
    assert_nil(directives.version)
    assert_nil(directives.date)
    assert_nil(directives.fields)
    assert_nil(directives.start_date)
    assert_nil(directives.end_date)
    assert_nil(directives.remark)
  end

  def test_is_directive
    assert_false(LogDirectives.is_directive(""))
    assert_false(LogDirectives.is_directive("some"))
    assert_false(LogDirectives.is_directive("some# text"))
    assert_false(LogDirectives.is_directive(" #"))
    assert_false(LogDirectives.is_directive(" # text"))

    assert_true(LogDirectives.is_directive("#"))
    assert_true(LogDirectives.is_directive("# Some text"))
    assert_true(LogDirectives.is_directive("#Sometext"))
  end

  def test_process_info
    directives = LogDirectives.new()
    line = "#Version: 1.0\n"
    directives.process_info(line)
    assert_equal("1.0", directives.version)
  end

  def test_process_info_all
    directives = LogDirectives.new()
    for line in @@directives.split("\n")
      directives.process_info(line)
    end

    assert_equal("Some software thing", directives.software)
    assert_equal("1.0", directives.version)
    assert_equal("2000-01-01 12:00:00", directives.date)
    assert_equal(["date", "time", "ip", "method"], directives.fields)
    assert_equal("2001-01-01 12:00:00", directives.start_date)
    assert_equal("2002-01-01 12:00:00", directives.end_date)
    assert_equal("Some reamrk.", directives.remark)
  end

  def test_process_info_fields
    directives = LogDirectives.new()
    directives.process_info("#Fields: one")
    assert_equal(["one"], directives.fields)

    directives.process_info("#Fields: ")
    assert_empty(directives.fields)
  end
end
