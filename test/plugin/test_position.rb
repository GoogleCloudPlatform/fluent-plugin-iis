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


require 'fluent/plugin/position'
require 'test/unit'
require 'fileutils'


class PositionTest < Test::Unit::TestCase
  sub_test_case("Position") do
    @@path = "path/to/thing.log"
    @@last_directives_pos = 12
    @@last_read_pos = 28
    @@pos_string = "#{@@path} #{@@last_directives_pos} #{@@last_read_pos}"

    def test_init
      pos = Position.new(@@path)
      assert_equal(@@path, pos.path)
      assert_equal(-1, pos.last_directives_pos)
      assert_equal(-1, pos.last_read_pos)
    end

    def test_init_params
      pos = Position.new(@@path, @@last_directives_pos, @@last_read_pos)
      assert_equal(@@path, pos.path)
      assert_equal(@@last_directives_pos, pos.last_directives_pos)
      assert_equal(@@last_read_pos, pos.last_read_pos)
    end

    def test_to_s
      pos = Position.new(@@path)
      assert_equal("#{@@path} -1 -1", pos.to_s)
    end

    def test_params_to_s
      pos = Position.new(@@path, @@last_directives_pos, @@last_read_pos)
      assert_equal(@@pos_string, pos.to_s)
    end

    def test_from_string
      pos = Position.from_string(@@pos_string)
      assert_equal(@@path, pos.path)
      assert_equal(@@last_directives_pos, pos.last_directives_pos)
      assert_equal(@@last_read_pos, pos.last_read_pos)
    end

    def test_from_string_invalid
      assert_raise(ArgumentError) do
        Position.from_string("#{@@path} 12")
      end

      assert_raise(ArgumentError) do
        Position.from_string("#{@@path} 12 12 hi")
      end

      assert_raise(ArgumentError) do
        Position.from_string("#{@@path} 12 hi")
      end
    end
  end


  sub_test_case("PositionFile") do
    @@path_one = "path/to/one.log"
    @@path_two = "some/other/thing.log"
    @@path_three = "path/to/six.log"
    @@path_four = "another/one/log"

    def setup
      super
      FileUtils.mkdir_p(TMP_DIR)

      File.open(PATH, "wb") { |f|
        f.puts "#{@@path_one} 0 0"
        f.puts "#{@@path_two} 28 1002"
        f.puts "#{@@path_three} 88 90"
      }
    end

    def teardown
      super
      FileUtils.remove_entry(TMP_DIR)
    end

    TMP_DIR = File.dirname(__FILE__) + "/../tmp/position#{ENV['TEST_ENV_NUMBER']}"
    PATH = "#{TMP_DIR}/iis.log.pos"

    def test_init
      pos_file = PositionFile.new(PATH)
      assert_equal(3, pos_file.pos.size)
      assert_empty(pos_file.pos.keys - [@@path_one, @@path_two, @@path_three])
    end

    def test_get_position
      pos_file = PositionFile.new(PATH)
      pos = pos_file.get_position(@@path_two)
      assert_equal(@@path_two, pos.path)
      assert_equal(28, pos.last_directives_pos)
      assert_equal(1002, pos.last_read_pos)
    end

    def test_get_position_adds
      pos_file = PositionFile.new(PATH)
      pos = pos_file.get_position(@@path_four)
      assert_equal(@@path_four, pos.path)
      assert_equal(-1, pos.last_directives_pos)
      assert_equal(-1, pos.last_read_pos)
      assert_equal(4, pos_file.pos.size)
    end

    def test_remove_position
      pos_file = PositionFile.new(PATH)
      pos = pos_file.remove_position(@@path_two)
      assert_equal(@@path_two, pos.path)
      assert_equal(2, pos_file.pos.size)
      assert_empty(pos_file.pos.keys - [@@path_one, @@path_three])
    end

    def test_remove_position_invalid
      pos_file = PositionFile.new(PATH)
      assert_nil(pos_file.remove_position(@@path_four))
      assert_equal(3, pos_file.pos.size)
    end

    def test_write_to_file
      pos_file = PositionFile.new(PATH)
      pos_file.get_position(@@path_four)
      pos_file.remove_position(@@path_one)
      pos_file.remove_position(@@path_three)
      pos_file.write_to_file()

      pos_file_new = PositionFile.new(PATH)
      assert_equal(2, pos_file_new.pos.size)
      assert_empty(pos_file_new.pos.keys - [@@path_two, @@path_four])
    end
  end

end
