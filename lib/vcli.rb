require 'readline'

class Root

  def cd str
    case str
    when "brad"
      $context = EsxHost.new("brad")
    when "pit"
      $context = EsxHost.new("pit")
    end
  end

  def sub_element
    %w{brad pit}
  end

  def path
    "/"
  end

end

class EsxHost

  def initialize name
    @name = name
  end

  def cd str
    $context = EsxVms.new(self) if str == "vms"
  end

  def path
    "/#{@name}"
  end

  def sub_element
    %w{vms}
  end

end

class EsxVms

  def initialize parent
    @parent = parent
  end

  def cd str
    case str
    when "mangas"
      $context = EsxVm.new(self, "mangas")
    when "forge"
      $context = EsxVm.new(self, "forge")
    end
  end

  def path
    "#{@parent.path}/vms"
  end

  def sub_element
    %w{mangas forge}
  end

end

class EsxVm

  def initialize parent, name
    @parent = parent
    @name = name
  end

  def name arg1, arg2
    p @name, arg1, arg2
  end

  def path
    "#{@parent.path}/#{@name}"
  end

end

$context = Root.new

def cd path
  unless $context.respond_to? :sub_element
    raise "Error : no sub element"
  end
  unless $context.sub_element.index(path)
    raise "Error : No sub element named #{path}"
  end
  $context.send(:cd, path)
end

def run command, *args
end

if ARGV.count > 0
  paths = ARGV.shift.split('.')
  command = paths.pop
  paths.each do |path|
    cd path
  end
  $context.send(command, *ARGV)
  exit 0
end

Readline.completion_append_character = " "
Readline.completion_proc = Proc.new do |str|
  if $context.respond_to? :sub_element
    $context.sub_element.grep( /^#{Regexp.escape(str)}/ )
  else
    []
  end
end

while line = Readline.readline("VMWareCli #{$context.path}> ", true)
  args = line.split(' ')
  command = args.shift.to_sym
  case command
  when :ls
    unless $context.respond_to? :sub_element
      puts "Error : no sub element"
      next
    end
    $context.sub_element.each do |element|
      puts element
    end
    next
  when :cd
    args[0].split('/').each do |path|
      begin
        cd path
      rescue Exception => e
        puts "Error : Unable to go to #{path}"
      end
    end
    next
  end
  begin
    $context.send(command, *args)
  rescue Exception => e
    puts "Error : #{e}, context #{$context}"
  end
end
