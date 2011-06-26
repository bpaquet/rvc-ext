
opts :show do
  summary "Show autostart config"
  arg :folder, nil, :lookup => VIM::Folder
end

def show folder
  cache = {}
  max = folder.children.keys.map{|k| k.size}.max || 0
  
  folder.children.keys.sort.each do |key|
    vm = folder.children[key]
    host = vm.summary.runtime.host
    config = cache[host]
    unless config
      config = host.config
      cache[host] = config
    end
    info = ""
    config.autoStart.powerInfo.each do |powerInfo|
      info = "Autostart enabled.   Stop action : #{powerInfo.stopAction}" if vm == powerInfo.key
    end
    puts sprintf("%#{max}s : %s", key, info)
  end
end