
opts :reconfigure_all_net_device do
  summary "Reconfigure all networks adapter to a virtual machine"
  arg :vm, nil, :lookup => VIM::VirtualMachine
  opt :type, "Adapter type", :default => 'vmxnet3'
end

def reconfigure_all_net_device vm, opts
  vm.config.hardware.device.grep(VIM::VirtualEthernetCard).each do |eth|
    puts "Reconfigure #{eth.deviceInfo.label} to #{opts[:type]} for #{vm.name}"
    remove_device vm, eth.deviceInfo.label
    add_net_device vm, opts.merge(:network => eth.backing.network.name)
  end
end

opts :move_into_resource_pool do
  summary "Move vms into resource pool"
  arg :vm, nil, :lookup => VIM::VirtualMachine
  arg :pool, "Resource pool", :short => 'p', :type => :string, :lookup => VIM::ResourcePool
end

def move_into_resource_pool vm, pool
  pool.MoveIntoResourcePool(:list => [vm])
end
