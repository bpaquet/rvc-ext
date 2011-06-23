
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
  opts[:disksize] = 4000000
  opts[:diskthin] = true
  opts[:cpucount] = src.summary.config.numCpu
  opts[:memory] = src.summary.config.memorySizeMB
  opts[:guest_id] = src.config.guestId
  opts[:network] = src.config.hardware.device.grep(VIM::VirtualEthernetCard)[0].backing.network.name if local
  vm = RVC::MODULES['vm'].create dest, opts
  vm.config.hardware.device.grep(VIM::VirtualDisk).each do |disk|
    label = disk.deviceInfo.label
    RVC::MODULES['vm'].remove_disk vm, label
  end
  puts ">>> Clone created : #{vm}"
  puts ">>> Duplicating disk"
  src.config.hardware.device.grep(VIM::VirtualDisk).each do |disk|
    RVC::MODULES['vm'].add_scsi_disk vm, {:disksize => disk.capacityInKB, :diskthin => disk.backing.thinProvisioned}
    new_disk = vm.config.hardware.device.grep(VIM::VirtualDisk).last
    progress [vm._connection.serviceContent.virtualDiskManager.DeleteVirtualDisk_Task(
      :name => new_disk.backing.fileName
    )]
    progress [vm._connection.serviceContent.virtualDiskManager.CopyVirtualDisk_Task(
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