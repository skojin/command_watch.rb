#!/usr/bin/ruby

require 'yaml'
require 'open3'

class CommandMemory
  def initialize(name, new_value)
    @path = "#{DB_PATH}/#{name}"
    @new_value = new_value
  end

  def prev_value
    return @prev_value if defined? @prev_value
    @prev_value = File.read(@path) rescue nil
  end

  # if value changed from previous call
  def changed?
    prev_value != @new_value
  end

  def condition_chaned? # &:block val
    return true unless prev_value
    yield(@new_value.to_i) != yield(prev_value.to_i)
  end

  # save new value to db
  def commit!
    File.write(@path, @new_value)
  end
end


class Command
  attr_reader :name, :conf

  def initialize(name, conf)
    @name = name
    @conf = conf
  end



  def call
    return if ENV['ONLY'] && ENV['ONLY'] != name
    print name

    if conf.has_key?('enabled') && !conf['enabled']
      puts '  DISABLED'
      return
    end

    result, status = Open3.capture2e(conf['watch'])
    if conf['debug']
      puts
      p [:status, status.to_i, :result, result]
    end
    if status.to_i != 0 && conf['skip_error']
      puts "  BAD EXIT CODE #{status.to_i}, skip"
      return
    end

    result = result.to_s.strip rescue result
    @mem = CommandMemory.new(name, result)

    if changed?
      puts ' CHANGED'

      command = conf['do'].gsub(/\$(1|2|lt|gt|eq)/) do |match|
        if match == '$1'
          result.to_s.gsub('"', '\"')
        elsif match == '$2'
          @mem.prev_value.to_s.gsub('"', '\"')
        elsif match =~ /\$(lt|gt|eq|ne)/
          conf[$1]
        end
      end
      ok = false
      if !ENV['DEBUG']
        _, do_status = Open3.capture2(command, :stdin_data => result)
        ok = do_status.success?
      else
        puts "$ #{command}\n"
      end

      @mem.commit! if ok && !ENV['DEBUG']
    else
      @mem.commit! if !ENV['DEBUG']
      puts ' SAME'
    end
  end

  def changed?
    return false unless @mem.changed?
    if conf['lt']
      @mem.condition_chaned?{|v| v < conf['lt'].to_i }
    elsif conf['gt']
      @mem.condition_chaned?{|v| v > conf['gt'].to_i }
    elsif conf['eq']
      @mem.condition_chaned?{|v| v == conf['eq'].to_i }
    else
      true
    end
  end

end


if __FILE__ == $0
  DB_PATH = '.db'
  CONFIG_PATH = 'config.yml'

  Dir.mkdir(DB_PATH) rescue nil
  CONFIG = YAML.load_file(CONFIG_PATH)

  CONFIG.each do |name, conf|
    Command.new(name, conf).call
  end
end
