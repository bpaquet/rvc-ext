require 'yaml'

opts :compute_resource_stats do
  summary "Give a compute resource stats in yml mode"
  arg :yml_file, "Target yml file"
  arg :obj, "Compute resource", :required => false, :default => '.', :lookup => VIM::ComputeResource
end

def compute_resource_stats yml_file, object
  _dump_yml object.stats, yml_file
end

opts :ls_vms_simple do
  summary "List virtuals machines, simple info in yml mode"
  arg :yml_file, "Target yml file"
  arg :obj, "Directory to list", :required => false, :default => '.', :lookup => VIM::Folder
end

def ls_vms_simple yml_file, object
  data = []
  object.children.each do |name, vm|
    data << {:name => name, :powerState => vm.runtime.powerState}
  end
  _dump_yml data, yml_file
end

opts :ls_vms do
  summary "List virtuals machines in yml mode"
  arg :yml_file, "Target yml file"
  arg :obj, "Directory to list", :required => false, :default => '.', :lookup => Object
end

opts :vm do
  summary "Give info on a specific vm"
  arg :yml_file, "Target yml file"
  arg :obj, "VM to list", :lookup => VIM::VirtualMachine
end

def vm yml_file, vm
 yml = {:summary => _to_yml(vm.summary), :config => _to_yml(vm.config)}
 _dump_yml yml, yml_file
end

def ls_vms yml_file, object
  yml = _search_vms object
  _dump_yml yml, yml_file
end

def _dump_yml yml, file
  File.open(file, 'w' ) do |f|
    YAML.dump(yml, f)
  end
end

def _search_vms object
  content = {}
  object.children.each_pair do |k, v|
    if v.is_a?(RVC::FakeFolder) || v.is_a?(RbVmomi::VIM::ResourcePool)
      subtree = _search_vms v
      content[k.to_sym] = subtree if subtree.size > 0
    elsif v.is_a? RbVmomi::VIM::VirtualMachine
      content[v.name] = _to_yml v.summary
    end
  end
  content
end

def _to_yml object
  content = {}
  object.props.each_pair do |key, value|
    result = _process_object value
    content[key] = result if result
  end
  content
end

def _process_object o
  if o.is_a?(String) || o.is_a?(Fixnum)
    o
  elsif o.is_a? Array
    o.map{|oo| _process_object oo}
  elsif o.respond_to? :props
    intern = _to_yml o
    o.is_a?(RbVmomi::VIM::VirtualDevice) ? intern.merge({:class => o.class.name, :is_network => o.is_a?(RbVmomi::VIM::VirtualEthernetCard)}) : intern
  else
    # puts "Unknown object type #{o.class}"
    nil
  end
end
