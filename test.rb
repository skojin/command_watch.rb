#!/usr/bin/ruby

require './command_watch'
require 'test/unit'
require 'fileutils'
extend Test::Unit::Assertions


Dir.mkdir('tmp') rescue nil
Dir.chdir 'tmp'
DB_PATH = '.'

def test_command(conf)
  Dir['*'].each{|f| File.delete f }
  yield 'unit', conf
  Dir['*'].each{|f| File.delete f }
end

def command_result(filename = 'unit.do', delete: true)
  r = File.read(filename) rescue nil
  FileUtils.rm_f(filename) if delete
  r
end

# TESTS ARE BELOW

# test simple command
test_command('watch' => 'echo 111',
  'do' => 'echo $1 > unit.do') do |name, conf|
  # on first call call :do
  Command.new(name, conf).call
  assert_equal "111\n", command_result

  # result is same, :do not called
  Command.new(name, conf).call
  assert_nil command_result

  # result is changed, :do called
  conf['watch'] = 'echo 222'
  Command.new(name, conf).call
  assert_equal "222\n", command_result
end

# test command $1 and $2
test_command('watch' => 'echo 111',
  'do' => 'echo "$1-$2" > unit.do') do |name, conf|
  Command.new(name, conf).call
  conf['watch'] = 'echo 222'
  Command.new(name, conf).call
  assert_equal "222-111\n", command_result
end

# test :enabled
test_command('watch' => 'echo 111',
  'enabled' => false,
  'do' => 'echo $1 > unit.do') do |name, conf|
    Command.new(name, conf).call
    assert_nil command_result
    conf['enabled'] = true
    Command.new(name, conf).call
    assert_equal "111\n", command_result
end

# test :skip_error
test_command('watch' => 'echo 111 | grep 222', # grep if not found exit with 256 code
  'skip_error' => true, # with this option do not stop command processing, useful if curl sometimes return bad code
  'do' => 'echo $1 > unit.do') do |name, conf|
    Command.new(name, conf).call
    assert_nil command_result

    conf['skip_error'] = false
    Command.new(name, conf).call
    assert_equal "\n", command_result
end

# test :skip_empty
test_command('watch' => 'echo', # grep if not found exit with 256 code
  'skip_empty' => true, #
  'do' => 'echo $1 > unit.do') do |name, conf|
    Command.new(name, conf).call
    assert_nil command_result

    conf['skip_empty'] = false
    Command.new(name, conf).call
    assert_equal "\n", command_result
end

# less then
test_command('watch' => 'echo 10',
  'lt' => '5',
  'do' => 'echo "$1 - $lt" > unit.do') do |name, conf|
    Command.new(name, conf).call
    assert_equal "10 - 5\n", command_result
    conf['watch'] = 'echo 5'
    Command.new(name, conf).call
    assert_nil command_result

    conf['watch'] = 'echo 4'
    Command.new(name, conf).call
    assert_equal "4 - 5\n", command_result
end

# great then
test_command('watch' => 'echo 1',
  'gt' => '5',
  'do' => 'echo "$1 - $gt" > unit.do') do |name, conf|
    Command.new(name, conf).call
    assert_equal "1 - 5\n", command_result
    conf['watch'] = 'echo 5'
    Command.new(name, conf).call
    assert_nil command_result

    conf['watch'] = 'echo 6'
    Command.new(name, conf).call
    assert_equal "6 - 5\n", command_result
end

# equal - :do when equal or not equal
test_command('watch' => 'echo 5',
  'eq' => '5',
  'do' => 'echo "$1 - $eq" > unit.do') do |name, conf|
    Command.new(name, conf).call
    assert_equal "5 - 5\n", command_result
    Command.new(name, conf).call
    assert_nil command_result

    conf['watch'] = 'echo 6'
    Command.new(name, conf).call
    assert_equal "6 - 5\n", command_result
end

def test_parse_every_conf
  assert_equal 2 * 60, Command.new('test', 'every' => '2m').every
  assert_equal 60 * 60, Command.new('test', 'every' => '1h').every
  assert_equal 60 * 60 * 24 * 2, Command.new('test', 'every' => '2d').every
end
test_parse_every_conf


# every minutes
test_command('watch' => 'touch unit.wh && head -c 100 /dev/random | md5',
  'every' => '5m',
  'do' => 'echo $1 > unit.do') do |name, conf|
    Command.new(name, conf).call
    first_result = command_result(delete: false)
    assert_not_nil first_result
    assert_not_nil command_result('unit.wh')
    # second call, 5 min not passed, watch command should not be called
    Command.new(name, conf).call
    assert_equal first_result, command_result(delete: false)
    assert_nil command_result('unit.wh')

    # almost 5 minutes
    FileUtils.touch 'unit', :mtime => (Time.now - (5*60 - 10))
    Command.new(name, conf).call
    assert_equal first_result, command_result(delete: false)
    assert_nil command_result('unit.wh')

    # after 5 minutes
    FileUtils.touch 'unit', :mtime => (Time.now - (5*60 + 1))
    Command.new(name, conf).call
    assert_not_equal first_result, command_result
    assert_not_nil command_result('unit.wh')
end
