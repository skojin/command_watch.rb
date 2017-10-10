#!/usr/bin/ruby

require 'yaml'
require 'open3'


DB_PATH = '.db'
CONFIG_PATH = 'config.yml'

class CommandMemory
  def initialize(name, new_value)
    @path = "#{DB_PATH}/#{name}"
    @new_value = new_value
  end

  def prev_value
    return @value if defined? @value
    @value = File.read(@path) rescue nil
  end

  # if value changed from previous call
  def changed?
    prev_value != @new_value
  end

  # save new value to db
  def commit!
    File.write(@path, @new_value)
  end
end



Dir.mkdir(DB_PATH) rescue nil
CONFIG = YAML.load_file(CONFIG_PATH)

CONFIG.each do |name, conf|
  print name
  if conf.has_key?('enabled') && !conf['enabled']
    puts '  DISABLED'
    next
  end


  result, status = Open3.capture2e(conf['watch'])
  mem = CommandMemory.new(name, result)
  if mem.changed?
    puts ' CHANGED'
    command = conf['do'].gsub(/\$[12]/) do |match|
      if match == '$1'
        result.to_s.gsub('"', '\"')
      elsif match == '$2'
        mem.prev_value.to_s.gsub('"', '\"')
      end
    end
    _, do_status = Open3.capture2(command, :stdin_data => result)

    mem.commit! if do_status.success? && !ENV['DEBUG']
  else
    puts ' SAME'
  end

end


