#!/usr/bin/ruby

require './command_watch'
require 'test/unit'
extend Test::Unit::Assertions


Dir.mkdir('tmp') rescue nil
Dir.chdir 'tmp'
DB_PATH = '.'

def test_command(conf)
  Dir['*'].each{|f| File.delete f }
  yield 'unit', conf
  Dir['*'].each{|f| File.delete f }
end

def command_result
  r = File.read('unit.do') rescue nil
  File.delete('unit.do')  rescue nil
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
  'do' => 'echo $1-$2 > unit.do') do |name, conf|
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
