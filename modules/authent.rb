require 'yaml'

config_file = ENV['RVC_AUTHENT_YML'] || 'rvc.authent.yml'

if File.exist? config_file
  config = YAML.load(File.read(config_file))
  (0..ARGV.count - 1).each do |k|
    host = ARGV[k]
    host_config = config[host.to_sym]
    if host_config
      cmd = "#{host_config[:login] || 'root'}:#{host_config[:password]}@#{host_config[:host] || host}"
      # puts "Using authent from config for #{host}"
      ARGV[k] = cmd
    end
  end    
end