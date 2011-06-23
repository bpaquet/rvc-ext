
opts :reconfigure_all_net_device do
  summary "Reconfigure all networks adapter to a virtual machine"
  arg :vm, nil, :lookup => VIM::VirtualMachine
  opt :type, "Adapter type", :default => 'vmxnet3'
end

def reconfigure_all_net_device vm, opts
  vm.config.hardware.device.grep(VIM::VirtualEthernetCard).each do |eth|
    puts "Reconfigure #{eth.deviceInfo.label} to #{opts[:type]}"
    remove_device vm, eth.deviceInfo.label
    add_net_device vm, opts.merge(:network => eth.backing.network.name)
  end
end
