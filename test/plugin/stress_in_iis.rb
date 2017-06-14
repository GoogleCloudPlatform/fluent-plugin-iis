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

require 'fileutils'
require 'fluent/plugin/in_iis'
require 'fluent/test'
require 'fluent/test/driver/input'
require 'test/unit'


class IISInputBenchmark < Test::Unit::TestCase

  def setup
    super
    Fluent::Test.setup
    FileUtils.mkdir_p(TMP_DIR)
    @rand = Random.new()
  end

  def teardown
    super
    Fluent::Engine.stop
    FileUtils.remove_entry(TMP_DIR)
  end

  TMP_DIR = File.dirname(__FILE__) + "/../tmp/iis#{ENV['TEST_ENV_NUMBER']}"

  def test_emit_entries_small
    helper_test_emit_entries(10, 100, 10)
  end

  def test_emit_entries_large
    helper_test_emit_entries(100, 10000, 1000)
  end

  def test_emit_entries_one_small_file
    helper_test_emit_entries(1, 2000, 2)
  end

  def test_emit_entries_one_large_file
    helper_test_emit_entries(1, 100000, 100)
  end

  def test_emit_entries_many_small_files
    helper_test_emit_entries(10000, 10, 10000)
  end

  def helper_test_emit_entries(num_files, num_entries_per_file, expect_emits)
    rand_num = @rand.rand(100000000)
    test_dir = "#{TMP_DIR}/#{rand_num}"
    FileUtils.mkdir_p(test_dir)

    conf = Fluent::Config::Element.new("ROOT", "",
    {
      "read_log_entires" => 1,
      "refresh_logs_list" => 1,
      "write_position_file" => 1,
      "path" => "#{test_dir}/iis-*.log",
      "pos_file" => "#{test_dir}/iis.log.pos"
    }, [])

    for i in 0...num_files
      File.open("#{test_dir}/iis-#{i}.log", "wb") {|f|
        f.puts "#Fields: date time ip method"
        for j in 0...(num_entries_per_file - 1)
          f.puts "2017-03-05 17:18:49 127.0.0.#{j} GET"
        end
      }
    end

    driver = Fluent::Test::Driver::Input.new(Fluent::IISInput).configure(conf)

    start_time = Time.now()
    driver.run(expect_emits: expect_emits)
    end_time = Time.now()
    total_time = end_time - start_time

    puts "\n"
    puts "== Test Results =="
    puts "Total time (sec):  #{total_time}"
    puts "Total number of entries: #{num_files * num_entries_per_file}"
    puts "Entries per second: #{num_files * num_entries_per_file / total_time}"
    puts "Number of files: #{num_files}"
    puts "Number of lines per file: #{num_entries_per_file}"
    puts "\n"

    events = driver.events
    assert_equal(num_files * num_entries_per_file, events.length)

    FileUtils.remove_entry(test_dir)
  end

end

