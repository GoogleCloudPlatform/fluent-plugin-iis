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
require 'fluent/system_config'
require 'fluent/test'
require 'fluent/test/driver/input'
require 'test/unit'

class IISInputTest < Test::Unit::TestCase

  def setup
    super
    Fluent::Test.setup
    FileUtils.mkdir_p(TMP_DIR)
  end

  def teardown
    super
    Fluent::Engine.stop
    FileUtils.remove_entry(TMP_DIR)
  end

  def create_driver(config)
    Fluent::Test::Driver::Input.new(Fluent::IISInput).configure(config)
  end

  TMP_DIR = File.dirname(__FILE__) + "/../tmp/iis#{ENV['TEST_ENV_NUMBER']}"
  TMP_LOG = "#{TMP_DIR}/iis.log"
  TMP_POS = "#{TMP_DIR}/iis.log.pos"

  BASE_CONFIG = Fluent::Config::Element.new("ROOT", "",
    {
      "read_log_entires" => 1,
      "refresh_logs_list" => 1,
      "write_position_file" => 1
    }, [])

  CONFIG = BASE_CONFIG + Fluent::Config::Element.new("", "",
    {
      "path" => TMP_LOG,
    }, [])

  CONFIG_POS = CONFIG + Fluent::Config::Element.new("", "",
    {
      "pos_file" => TMP_POS
    }, [])

  CONFIG_GLOB_PATH = BASE_CONFIG + Fluent::Config::Element.new("", "",
    {
      "path" => "#{TMP_DIR}/*.log",
    }, [])

  CONFIG_PROCESS = CONFIG + Fluent::Config::Element.new("", "",
    {
      "process_logs" => true
    }, [])

  def test_emit_entry
    driver = create_driver(CONFIG)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "wb") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("17:18:49", "GET")
      }
    end

    events = driver.events
    assert_equal(2, events.length)
    check_simple_directive(events[0][2])
    assert('iis', events[1][0])
    check_simple_entry(events[1][2], "17:18:49", "GET")
  end

  def test_emit_entries
    driver = create_driver(CONFIG)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "w") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("17:18:49", "GET")
        f.puts create_simple_entry("17:19:49", "POST")
        f.puts create_simple_entry("17:20:49", "GET")
        f.puts create_simple_entry("17:21:49", "GET")
        f.puts create_simple_entry("17:22:49", "DELETE")
        f.puts create_simple_entry("17:23:49", "GET")
        f.puts create_simple_entry("17:24:49", "GET")
        f.puts create_simple_entry("17:25:49", "PUT")
        f.puts create_simple_entry("17:26:49", "GET")
      }
    end

    events = driver.events
    assert_equal(10, events.length)
    check_simple_directive(events[0][2])
    check_simple_entry(events[1][2], "17:18:49", "GET")
    check_simple_entry(events[2][2], "17:19:49", "POST")
    check_simple_entry(events[3][2], "17:20:49", "GET")
    check_simple_entry(events[4][2], "17:21:49", "GET")
    check_simple_entry(events[5][2], "17:22:49", "DELETE")
    check_simple_entry(events[6][2], "17:23:49", "GET")
    check_simple_entry(events[7][2], "17:24:49", "GET")
    check_simple_entry(events[8][2], "17:25:49", "PUT")
    check_simple_entry(events[9][2], "17:26:49", "GET")
  end

  def test_pos_file
    driver = create_driver(CONFIG_POS)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "w") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("17:18:49", "GET")
        f.puts create_simple_entry("17:19:49", "POST")
        f.puts create_simple_entry("17:20:49", "GET")
        f.puts create_simple_entry("17:21:49", "GET")
      }
    end

    events = driver.events
    assert_equal(5, events.length)
    check_simple_directive(events[0][2])
    check_simple_entry(events[1][2], "17:18:49", "GET")
    check_simple_entry(events[2][2], "17:19:49", "POST")
    check_simple_entry(events[3][2], "17:20:49", "GET")
    check_simple_entry(events[4][2], "17:21:49", "GET")

    driver_two = create_driver(CONFIG_POS)
    driver_two.run(expect_emits: 0)
    events = driver_two.events
    assert_equal(0, events.length)

    driver_three = create_driver(CONFIG_POS)
    driver_three.run(expect_emits: 1) do
      File.open(TMP_LOG, "a") {|f|
        f.puts create_simple_entry("17:22:49", "DELETE")
        f.puts create_simple_entry("17:23:49", "GET")
        f.puts create_simple_entry("17:24:49", "GET")
      }
    end

    events = driver_three.events
    assert_equal(3, events.length)
    check_simple_entry(events[0][2], "17:22:49", "DELETE")
    check_simple_entry(events[1][2], "17:23:49", "GET")
    check_simple_entry(events[2][2], "17:24:49", "GET")

    driver_four = create_driver(CONFIG_POS)
    driver_four.run(expect_emits: 0)
    events = driver_four.events
    assert_equal(0, events.length)
  end

  def test_read_line_limit
    conf = CONFIG + Fluent::Config::Element.new("", "", { "read_line_limit" => 2 }, [])
    driver = create_driver(conf)
    driver.run(expect_emits: 3) do
      File.open(TMP_LOG, "w") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("17:18:49", "GET")
        f.puts create_simple_entry("17:19:49", "POST")
        f.puts create_simple_entry("17:20:49", "GET")
        f.puts create_simple_entry("17:21:49", "GET")
        f.puts create_simple_entry("17:22:49", "DELETE")
      }
    end

    events = driver.events
    assert_equal(6, events.length)

    check_simple_directive(events[0][2])

    check_simple_entry(events[1][2], "17:18:49", "GET")
    check_simple_entry(events[2][2], "17:19:49", "POST")
    check_simple_entry(events[3][2], "17:20:49", "GET")
    check_simple_entry(events[4][2], "17:21:49", "GET")
    check_simple_entry(events[5][2], "17:22:49", "DELETE")
  end

  def test_tag
    conf = CONFIG + Fluent::Config::Element.new("", "", { "tag" => 'new-tag' }, [])
    driver = create_driver(conf)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "w") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("17:18:49", "GET")
      }
    end

    events = driver.events
    assert_equal(2, events.length)
    assert('new-tag', events[0][0])
    assert('new-tag', events[1][0])
  end

  def test_glob_paths
    driver = create_driver(CONFIG_GLOB_PATH)
    driver.run(expect_emits: 3) do
      File.open("#{TMP_DIR}/log_one.log", "w") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("17:00:00", "GET")
      }

      File.open("#{TMP_DIR}/some.log", "w") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("19:00:00", "DELETE")
      }

      File.open("#{TMP_DIR}/anotherLog.log", "w") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("21:00:00", "POST")
      }
    end

    events = driver.events
    assert_equal(6, events.length)

    result = events.select { |event| event[2]['message'] ==  create_simple_directive() }
    assert_equal(3, result.length)

    result = events.select { |event| event[2]['message'].start_with?("2017-03-05 17") }
    assert_equal(1, result.length)

    result = events.select { |event| event[2]['message'].start_with?("2017-03-05 19") }
    assert_equal(1, result.length)

    result = events.select { |event| event[2]['message'].start_with?("2017-03-05 21") }
    assert_equal(1, result.length)
  end

  def test_multiple_paths
    conf = BASE_CONFIG + Fluent::Config::Element.new("", "", {
      "path" => "#{TMP_DIR}/log_one.log, #{TMP_DIR}/some.log,#{TMP_DIR}/anotherLog.log",
    }, [])
    driver = create_driver(conf)
    driver.run(expect_emits: 3) do
      File.open("#{TMP_DIR}/log_one.log", "w") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("17:00:00", "GET")
      }

      File.open("#{TMP_DIR}/some.log", "w") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("19:00:00", "DELETE")
      }

      File.open("#{TMP_DIR}/anotherLog.log", "w") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("21:00:00", "POST")
      }
    end

    events = driver.events
    assert_equal(6, events.length)

    result = events.select { |event| event[2]['message'] ==  create_simple_directive() }
    assert_equal(3, result.length)

    result = events.select { |event| event[2]['message'].start_with?("2017-03-05 17") }
    assert_equal(1, result.length)

    result = events.select { |event| event[2]['message'].start_with?("2017-03-05 19") }
    assert_equal(1, result.length)

    result = events.select { |event| event[2]['message'].start_with?("2017-03-05 21") }
    assert_equal(1, result.length)
  end

  def test_process_logs
    driver = create_driver(CONFIG_PROCESS)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "w") {|f|
        f.puts create_simple_directive()
        f.puts "2017-03-05 17:18:49 127.0.0.1 GET"
      }
    end

    events = driver.events
    assert_equal(2, events.length)
    check_simple_directive(events[0][2])
    check_processed_simple_entry(events[1][2], "17:18:49", "GET")
  end

  def test_process_logs_multiple
    driver = create_driver(CONFIG_PROCESS)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "w") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("17:18:49", "GET")
        f.puts create_simple_entry("17:19:49", "POST")
        f.puts create_simple_entry("17:20:49", "GET")
        f.puts create_simple_entry("17:21:49", "GET")
        f.puts create_simple_entry("17:22:49", "DELETE")
        f.puts create_simple_entry("17:23:49", "GET")
        f.puts create_simple_entry("17:24:49", "GET")
        f.puts create_simple_entry("17:25:49", "PUT")
        f.puts create_simple_entry("17:26:49", "GET")
      }
    end

    events = driver.events
    assert_equal(10, events.length)
    check_simple_directive(events[0][2])
    check_processed_simple_entry(events[1][2], "17:18:49", "GET")
    check_processed_simple_entry(events[2][2], "17:19:49", "POST")
    check_processed_simple_entry(events[3][2], "17:20:49", "GET")
    check_processed_simple_entry(events[4][2], "17:21:49", "GET")
    check_processed_simple_entry(events[5][2], "17:22:49", "DELETE")
    check_processed_simple_entry(events[6][2], "17:23:49", "GET")
    check_processed_simple_entry(events[7][2], "17:24:49", "GET")
    check_processed_simple_entry(events[8][2], "17:25:49", "PUT")
    check_processed_simple_entry(events[9][2], "17:26:49", "GET")
  end


  def test_switch_directives
    driver = create_driver(CONFIG_PROCESS + CONFIG_POS)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "w") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("17:18:49", "GET")
        f.puts create_simple_entry("17:19:49", "POST")
        f.puts "#Fields: ip time method date"
        f.puts "127.0.0.1 17:20:49 GET 2017-03-05"
      }
    end

    events = driver.events
    assert_equal(5, events.length)
    assert_equal(create_simple_directive(), events[0][2]['message'])
    check_processed_simple_entry(events[1][2], "17:18:49", "GET")
    check_processed_simple_entry(events[2][2], "17:19:49", "POST")
    assert_equal("#Fields: ip time method date", events[3][2]['message'])
    check_processed_simple_entry(events[4][2], "17:20:49", "GET")

    driver_three = create_driver(CONFIG_PROCESS + CONFIG_POS)
    driver_three.run(expect_emits: 1) do
      File.open(TMP_LOG, "a") {|f|
        f.puts "127.0.0.1 17:21:49 GET 2017-03-05"
        f.puts "#Fields: ip method time date"
        f.puts "127.0.0.1 GET 17:22:49 2017-03-05"
        f.puts "127.0.0.1 POST 17:23:49 2017-03-05"
      }
    end

    events = driver_three.events
    assert_equal(4, events.length)
    check_processed_simple_entry(events[0][2], "17:21:49", "GET")
    assert_equal("#Fields: ip method time date", events[1][2]['message'])
    check_processed_simple_entry(events[2][2], "17:22:49", "GET")
    check_processed_simple_entry(events[3][2], "17:23:49", "POST")
  end


  def test_complex_directives
    driver = create_driver(CONFIG)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "w") {|f|
        f.puts "#Version: 1.0"
        f.puts "#Software: Some software"
        f.puts create_simple_directive()
        f.puts "#Remark: Some remake"
        f.puts create_simple_entry("17:18:49", "GET")
      }
    end

    events = driver.events
    assert_equal(5, events.length)
    assert_equal("#Version: 1.0", events[0][2]['message'])
    assert_equal("#Software: Some software", events[1][2]['message'])
    assert_equal(create_simple_directive(), events[2][2]['message'])
    assert_equal("#Remark: Some remake", events[3][2]['message'])
  end

  def test_complex_directives_use_date
    driver = create_driver(CONFIG)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "w") {|f|
        f.puts "#Date: 2017-03-05 17:18:49"
        f.puts "#Fields: time ip method"
        f.puts "17:19:49 127.0.0.1 GET"
      }
    end

    events = driver.events
    assert_equal(3, events.length)
    timestamp = Time.parse("2017-03-05 17:19:49")
    event = events[2][2]
    assert_equal("17:19:49 127.0.0.1 GET", event['message'])
    assert_equal(timestamp.tv_sec, event['timestamp']['seconds'])
    assert_equal(timestamp.tv_nsec, event['timestamp']['nanos'])
  end

  def test_complex_directives_use_date_time
    driver = create_driver(CONFIG)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "w") {|f|
        f.puts "#Date: 2017-03-05 17:18:49"
        f.puts "#Fields: ip method"
        f.puts "127.0.0.1 GET"
      }
    end

    events = driver.events
    assert_equal(3, events.length)
    timestamp = Time.parse("2017-03-05 17:18:49")
    event = events[2][2]
    assert_equal("127.0.0.1 GET", event['message'])
    assert_equal(timestamp.tv_sec, event['timestamp']['seconds'])
    assert_equal(timestamp.tv_nsec, event['timestamp']['nanos'])
  end

  def test_watch_new_file
    driver = create_driver(CONFIG_GLOB_PATH)
    driver.run(shutdown: false)
    watched_files = driver.instance.instance_variable_get(:@watched_files)

    sleep(2)
    assert_empty(watched_files)

    File.open(TMP_LOG, "w") { |f| f.puts create_simple_directive() }
    File.open("#{TMP_DIR}/another.log", "w") { |f| f.puts create_simple_directive() }
    File.open("#{TMP_DIR}/third.log", "w") { |f| f.puts create_simple_directive() }
    sleep(2)

    assert_equal(3, watched_files.size)
    assert_true(watched_files.key?(TMP_LOG))
    assert_true(watched_files.key?("#{TMP_DIR}/another.log"))
    assert_true(watched_files.key?("#{TMP_DIR}/third.log"))

    driver.instance_shutdown
  end

  def test_remove_watch_of_deleted_file
    File.open(TMP_LOG, "w") { |f| f.puts create_simple_directive() }
    File.open("#{TMP_DIR}/another.log", "w") { |f| f.puts create_simple_directive() }
    File.open("#{TMP_DIR}/third.log", "w") { |f| f.puts create_simple_directive() }

    driver = create_driver(CONFIG_GLOB_PATH)
    driver.run(shutdown: false)
    watched_files = driver.instance.instance_variable_get(:@watched_files)

    sleep(2)
    assert_equal(3, watched_files.size)

    File.delete(TMP_LOG)
    File.delete("#{TMP_DIR}/another.log")
    sleep(2)

    assert_equal(1, watched_files.size)
    assert_true(watched_files.key?("#{TMP_DIR}/third.log"))

    driver.instance_shutdown
  end

  def test_pos_file_written
    driver = create_driver(CONFIG_POS)
    driver.run(expect_emits: 1, shutdown: false) do
      File.open(TMP_LOG, "w") {|f|
        f.puts create_simple_directive()
        f.puts create_simple_entry("17:18:49", "GET")
      }
    end
    sleep(2)

    pos_lines = File.readlines(TMP_POS)
    assert_equal(1, pos_lines.length)
    assert_true(pos_lines[0].start_with?(TMP_LOG))

    driver.instance_shutdown
  end

  data(true, false)
  def test_no_directives(data)
    conf = CONFIG + Fluent::Config::Element.new("", "", { "process_logs" => data }, [])
    driver = create_driver(conf)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "wb") {|f|
        f.puts create_simple_entry("17:18:49", "GET")
        f.puts create_simple_entry("17:19:49", "POST")
      }
    end

    events = driver.events
    assert_equal(2, events.length)

    event = events[0][2]
    assert_equal(2, event.size)
    assert_equal(create_simple_entry("17:18:49", "GET"), event['message'])
    assert_true(event['log-path'].include? "iis.log")

    event = events[1][2]
    assert_equal(2, event.size)
    assert_equal(create_simple_entry("17:19:49", "POST"), event['message'])
    assert_true(event['log-path'].include? "iis.log")
  end

  def test_too_few_directives
    driver = create_driver(CONFIG)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "w") {|f|
        f.puts "#Fields: date time ip"
        f.puts create_simple_entry("17:18:49", "GET")
      }
    end

    events = driver.events
    assert_equal(2, events.length)

    event = events[0][2]
    assert_equal(2, event.size)
    assert_equal("#Fields: date time ip", events[0][2]['message'])
    check_simple_entry(events[1][2], "17:18:49", "GET")
  end

  def test_too_many_directives
    driver = create_driver(CONFIG)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "w") {|f|
        f.puts "#Fields: date time ip method c-ip"
        f.puts create_simple_entry("17:18:49", "GET")
      }
    end

    events = driver.events
    assert_equal(2, events.length)

    event = events[0][2]
    assert_equal(2, event.size)
    assert_equal("#Fields: date time ip method c-ip", events[0][2]['message'])
    check_simple_entry(events[1][2], "17:18:49", "GET")
  end

  def test_too_few_directives_process
    driver = create_driver(CONFIG_PROCESS)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "w") {|f|
        f.puts "#Fields: date time ip"
        f.puts create_simple_entry("17:18:49", "GET")
      }
    end

    events = driver.events
    assert_equal(2, events.length)

    event = events[0][2]
    assert_equal(2, event.size)
    assert_equal("#Fields: date time ip", events[0][2]['message'])

    event = events[1][2]
    timestamp = Time.parse("2017-03-05 17:18:49")
    assert_equal(5, event.size)
    assert_equal("2017-03-05", event['date'])
    assert_equal("17:18:49", event['time'])
    assert_equal("127.0.0.1", event['ip'])
    assert_equal(timestamp.tv_sec, event['timestamp']['seconds'])
    assert_equal(timestamp.tv_nsec, event['timestamp']['nanos'])
    assert_true(event['log-path'].include? "iis.log")
  end

  def test_too_many_directives_process
    driver = create_driver(CONFIG_PROCESS)
    driver.run(expect_emits: 1) do
      File.open(TMP_LOG, "w") {|f|
        f.puts "#Fields: date time ip method c-ip"
        f.puts create_simple_entry("17:18:49", "GET")
      }
    end

    events = driver.events
    assert_equal(2, events.length)

    event = events[0][2]
    assert_equal(2, event.size)
    assert_equal("#Fields: date time ip method c-ip", events[0][2]['message'])

    event = events[1][2]
    timestamp = Time.parse("2017-03-05 17:18:49")
    assert_equal(7, event.size)
    assert_equal("2017-03-05", event['date'])
    assert_equal("17:18:49", event['time'])
    assert_equal("127.0.0.1", event['ip'])
    assert_equal("GET", event['method'])
    assert_nil(event['c-ip'])
    assert_equal(timestamp.tv_sec, event['timestamp']['seconds'])
    assert_equal(timestamp.tv_nsec, event['timestamp']['nanos'])
    assert_true(event['log-path'].include? "iis.log")
  end

  def create_simple_directive()
    return "#Fields: date time ip method"
  end

  def create_simple_entry(time, method)
    return "2017-03-05 #{time} 127.0.0.1 #{method}"
  end

  def check_simple_directive(event)
    assert_equal(2, event.size)
    assert_equal(create_simple_directive(), event['message'])
    assert_true(event['log-path'].include? "iis.log")
  end

  def check_simple_entry(event, time, method)
    timestamp = Time.parse("2017-03-05 #{time}")
    assert_equal(3, event.size)
    assert_equal(create_simple_entry(time, method), event['message'])
    assert_equal(timestamp.tv_sec, event['timestamp']['seconds'])
    assert_equal(timestamp.tv_nsec, event['timestamp']['nanos'])
    assert_true(event['log-path'].include? "iis.log")
  end

  def check_processed_simple_entry(event, time, method)
    timestamp = Time.parse("2017-03-05 #{time}")
    assert_equal(6, event.size)
    assert_equal("2017-03-05", event['date'])
    assert_equal(time, event['time'])
    assert_equal("127.0.0.1", event['ip'])
    assert_equal(method, event['method'])
    assert_equal(timestamp.tv_sec, event['timestamp']['seconds'])
    assert_equal(timestamp.tv_nsec, event['timestamp']['nanos'])
    assert_true(event['log-path'].include? "iis.log")
  end
end
