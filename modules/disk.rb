opts :extend do
  summary "Extend a disk"
  arg :disk, "Disk to resize", :lookup => VIM::Datastore::FakeDatastoreFile
  arg :new_capcity_kb, "New size in kB", :type => :int
end

def extend disk, new_capcity_kb
  name = "[#{disk.datastore.name}] #{disk.path}"
  err "Not a disk file #{name}" unless disk.info.is_a? RbVmomi::VIM::VmDiskFileInfo
  new_capcity_kb = new_capcity_kb.to_i
  err "New capacity #{new_capcity_kb} have to be upper than #{disk.info.capacityKb}" if new_capcity_kb <= disk.info.capacityKb
  disk.datastore._connection.serviceContent.virtualDiskManager.ExtendVirtualDisk_Task(
    :name => name,
    :newCapacityKb => new_capcity_kb,
    :eagerZero => false
  ).wait_for_completion
end
