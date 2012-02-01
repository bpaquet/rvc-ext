
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
  opts[:datastore] ||= default_datastore vmFolder
  opts[:pool] ||= default_pool vmFolder
  opts[:disksize] = 4000000
  opts[:diskthin] = true
  opts[:cpucount] = src.summary.config.numCpu
  opts[:memory] = src.summary.config.memorySizeMB
  opts[:guestid] = src.config.guestId
  opts[:network] = src.config.hardware.device.grep(VIM::VirtualEthernetCard)[0].backing.network.name if local
  if src.config.hardware.device.grep(VIM::VirtualSCSIController).size > 0
    opts[:controller] = src.config.hardware.device.grep(VIM::VirtualSCSIController)[0].class.to_s
  end
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
    when 1000
      "lsiLogic"
    when 200
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
    spec = VIM.FileBackedVirtualDiskSpec(
      :diskType => disk.backing.thinProvisioned ? :thin : :thick,
      :adapterType => type.to_sym,
      :capacityKb => disk.capacityInKB
    )
    _copy_disk src, disk.backing.fileName, vm, new_disk.backing.fileName, spec
    puts ">>> Clone #{vm} ok."
  end
end

opts :disk do
  summary "Copy disk"
  arg :src, "Source disk file", :lookup => VIM::Datastore::FakeDatastoreFile
  arg :dest, "Destination file", :lookup_parent => VIM::Datastore::FakeDatastoreFolder
  opt :direct, "When copying to another esx, do not clone disk before. In this case, disk is not renamed", :type => :boolean, :default => false
end

def disk src, dest, opts
  vmFolder, file = *dest
  _copy_disk src.datastore, src.datastore_path, vmFolder.datastore, "#{vmFolder.datastore_path}/#{file}", nil, opts[:direct]
end

def _copy_disk src_object, src_file, dest_object, dest_file, spec, direct = false
  if src_object._connection == dest_object._connection
    _local_copy_disk src_object, src_file, dest_file, spec
  else
    if direct
      _remote_copy_disk src_object, src_file, dest_object, dest_file
    else
      datastore, path = RVC::MODULES['datastore'].parse_file_url src_file
      tmp_directory = "[#{datastore}] /tmp_#{Time.now.to_i}_#{rand(65536)}"
      puts "Copy disk to tmp directory #{tmp_directory}"
      module_call :datastore, :mkdir_vm_path, src_object, tmp_directory
      begin
        new_src_file = "#{tmp_directory}/#{File.basename(dest_file)}"
        _local_copy_disk src_object, src_file, new_src_file, spec
        _remote_copy_disk src_object, new_src_file, dest_object, dest_file
      ensure
        module_call :datastore, :delete_vm_path, src_object, tmp_directory
      end
    end
  end
end

def _remote_copy_disk src_object, src_file, dest_object, dest_file
  files_to_copy = find_files_to_copy src_object, src_file
  puts "Duplicating disk on different host : #{src_object._connection._host} from #{src_file} to #{dest_object._connection._host} #{dest_file}"
  puts "Number of files to copy : #{files_to_copy.size}"
  files_to_copy.each do |file|
    target = "#{File.dirname(dest_file)}/#{File.basename(file)}"
    puts "Copying #{file} to #{target}"
    module_call :datastore, :copy_vm_path, src_object, file, dest_object, target
  end
end

def _local_copy_disk object, src_file, dest_file, spec
  puts "Duplicating disk on same host : from #{src_file} to #{dest_file}"
  progress_and_raise_if_error [object._connection.serviceContent.virtualDiskManager.CopyVirtualDisk_Task(
    :sourceName => src_file,
    :destName => dest_file,
    :spec => spec
  )]
end

def find_files_to_copy object, vmdk
  files_to_copy = [vmdk]
  RVC::MODULES['datastore'].download_in_tmp_file object, vmdk do |filename|
    content = File.read(filename)
    content.scan(/^RW [^\$]* "(.+\.vmdk)"$/).each do |match|
     files_to_copy.push "#{File.dirname(vmdk)}/#{match[0]}"
    end
    if content =~ /parentFileNameHint="(.*)"/
      files_to_copy = files_to_copy.concat find_files_to_copy(object, "#{File.dirname(vmdk)}/#{$1}")
    end
  end
  files_to_copy
end

def default_dc object
  object._connection.root.children.first[1]
end

def default_datastore object
  default_dc(object).children["datastore"].children.values[0]
end

def default_pool object
  default_dc(object).children["host"].children.values[0].children["resourcePool"]
end