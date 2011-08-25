
opts :shutdown do
  summary "Shutdown a host"
  arg :host, nil, :lookup => VIM::HostSystem, :multi => true
  opt :force, "Shutdown even if in maintenance mode", :default => false
end

def reboot hosts, opts
  tasks hosts, :ShutdownHost, :force => opts[:force]
end