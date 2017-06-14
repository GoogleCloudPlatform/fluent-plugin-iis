#!/usr/bin/env rake

require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'

desc 'Run unit tests'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.test_files = FileList['test/plugin/test_*.rb']
  test.verbose = true
end

desc 'Run stress test'
Rake::TestTask.new(:stress) do |test|
  test.libs << 'lib' << 'test'
  test.test_files = FileList['test/plugin/stress_*.rb']
  test.verbose = true
end

task all: [:test]

task default: :all
