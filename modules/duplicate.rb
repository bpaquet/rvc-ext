
opts :vm do
  summary "Duplicate a vm, to local or remote host"
  arg :src, "Source VM", :lookup => VIM::VirtualMachine
  arg :name, "Destination", :lookup_parent => VIM::Folder
  opt :pool, "Resource pool", :short => 'p', :type => :string, :lookup => VIM::ResourcePool
  opt :datastore, "Datastore", :short => 'd', :type => :string, :lookup => VIM::Datastore
end

def vm src, dest, opts
  vmFolder, name = *dest
  err "Vm already exist #{name}" if vmFolder.children[name]
  puts ">>> Duplicating vm #{src.name} to #{name}"
  local = src._connection == vmFolder._connection
  opts[:datastore] ||= get_default_datastore vmFolder
  opts[:pool] ||= get_default_pool vmFolder
  opts[:disksize] = 4000000
  opts[:diskthin] = true
  opts[:cpucount] = src.summary.config.numCpu
  opts[:memory] = src.summary.config.memorySizeMB
  opts[:guestid] = src.config.guestId
  opts[:network] = src.config.hardware.device.grep(VIM::VirtualEthernetCard)[0].backing.network.name if local
  vm = RVC::MODULES['vm'].create(dest, opts)
  err "Unable to create vm" unless vm
  vm.config.hardware.device.grep(VIM::VirtualDisk).each do |disk|
    label = disk.deviceInfo.label
    module_call :vm, :remove_disk, vm, label
  end
  module_call :vm, :reconfigure_all_net_device, vm, {:type => 'vmxnet3'}
  puts ">>> Clone created."
  puts ">>> Duplicating disk"
  src.config.hardware.device.grep(VIM::VirtualDisk).each do |disk|
    type = case disk.controllerKey
    when 1000:
      "lsiLogic"
    when 200:
      "ide"
    else
      err "Unknown controller type #{disk.controllerKey}"
    end
    puts "Adding disk #{type}, size #{disk.capacityInKB}"
    module_call :vm, :add_disk, vm, {:type => type, :disksize => disk.capacityInKB, :diskthin => disk.backing.thinProvisioned}
    new_disk = vm.config.hardware.device.grep(VIM::VirtualDisk).last
    progress_and_raise_if_error [vm._connection.serviceContent.virtualDiskManager.DeleteVirtualDisk_Task(
      :name => new_disk.backing.fileName
    )]
    progress_and_raise_if_error [src._connection.serviceContent.virtualDiskManager.CopyVirtualDisk_Task(
      :sourceName => disk.backing.fileName,
      :destName => new_disk.backing.fileName,
      :spec => VIM.FileBackedVirtualDiskSpec(
        :diskType => :thin,
        :adapterType => :lsiLogic,
        :capacityKb => disk.capacityInKB
      )
    )]
    puts ">>> Clone #{vm} ok."
  end
end

def get_default_datastore object
  object._connection.root.children.first[1].children["datastore"].children.values[0]
end

def get_default_pool object
  object._connection.root.children.first[1].children["host"].children.values[0].children["resourcePool"]
end