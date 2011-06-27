
opts :show do
  summary "Show autostart config"
  arg :folder, nil, :lookup => VIM::Folder
end

def show folder
  cache = {}
  max = folder.children.keys.map{|k| k.size}.max || 0
  
  folder.children.keys.sort.each do |key|
    vm = folder.children[key]
    next unless vm.is_a? VIM::VirtualMachine
    host = vm.summary.runtime.host
    power_info = cache[host]
    unless power_info
      power_info = host.config.autoStart.powerInfo
      cache[host] = power_info
    end
    info = ""
    power_info.each do |powerInfo|
      info = "Autostart enabled.   Stop action : #{powerInfo.stopAction}" if vm == powerInfo.key
    end
    puts sprintf("%#{max}s : %s", key, info)
  end
end

opts :disable do
  summary "Disable autostart for a specific vm"
  arg :vm, nil, :lookup => VIM::VirtualMachine
end

def disable vm
  host = vm.summary.runtime.host
  autostart = host.config.autoStart
  to_be_disabled = nil
  autostart.powerInfo.each do |powerInfo|
    to_be_disabled = powerInfo if vm == powerInfo.key
  end
  err "Autostart is not enabled on #{vm.name}" unless to_be_disabled
  to_be_disabled.startAction = "None"
  to_be_disabled.stopAction = "None"
  host.configManager.autoStartManager.ReconfigureAutostart :spec => autostart
  true
end

opts :enable do
  summary "Enable autostart for a specific vm"
  arg :vm, nil, :lookup => VIM::VirtualMachine
  opt :stop_action, "Stop action", :default => "SystemDefault"
end

def enable vm, opts
  host = vm.summary.runtime.host
  autostart = host.config.autoStart
  power_info = nil
  autostart.powerInfo.each do |powerInfo|
    power_info = powerInfo if vm == powerInfo.key
  end
  err "Autostart is already enabled on #{vm.name}" if power_info
  a = VIM::AutoStartPowerInfo.new(
  :key => vm,
  :startAction => "PowerOn",
  :startDelay => -1,
  :startOrder => -1,
  :stopAction => opts[:stop_action],
  :stopDelay => -1,
  :waitForHeartbeat => "systemDefault"
  )
  autostart.powerInfo = autostart.powerInfo.push a
  host.configManager.autoStartManager.ReconfigureAutostart :spec => autostart
  true
end