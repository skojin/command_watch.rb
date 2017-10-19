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
  next if ENV['ONLY'] && ENV['ONLY'] != name

  print name
  if conf.has_key?('enabled') && !conf['enabled']
    puts '  DISABLED'
    next
  end

  result, status = Open3.capture2e(conf['watch'])
  if conf['debug']
    puts
    p [:status, status.to_i, :result, result]
  end
  if status.to_i != 0 && conf['skip_error']
    puts "  BAD EXIT CODE #{status.to_i}, skip"
    next
  end

  result = result.to_s.strip rescue result
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
    ok = false
    if !ENV['DEBUG']
      _, do_status = Open3.capture2(command, :stdin_data => result)
      ok = do_status.success?
    else
      puts "$ #{command}\n"
    end

    mem.commit! if ok && !ENV['DEBUG']
  else
    puts ' SAME'
  end

end


