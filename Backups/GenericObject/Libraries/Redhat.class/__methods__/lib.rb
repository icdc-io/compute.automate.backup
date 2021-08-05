require 'date'
require 'ovirtsdk4'

Backup  = $evm.vmdb(:GenericObjectDefinition).where(:name => "Backup").first
Restore = $evm.vmdb(:GenericObjectDefinition).where(:name => "Restore").first

def find_backup_storage
  ($evm.vmdb(:Storage).find_tagged_with(:any => '/backup_disk', :ns => '/managed/vm_disk_type') - $evm.vmdb(:Storage).find_tagged_with(:all => '/provisioning/false', :ns => '/managed')).last.ems_ref.split('/').last
end

def find_storage_for_recovery(disk_type)
  ($evm.vmdb(:Storage).find_tagged_with(:all => "/storage_type/#{disk_type}", :ns => "/managed") - $evm.vmdb(:Storage).find_tagged_with(:all => '/provisioning/false', :ns => '/managed')).select { |x| x.storage_domain_type == "data" }.sort_by(&:free_space).last.ems_ref.split('/').last
end

def establish_connection(vm)
  vm.ext_management_system.connect
end

def replace_name_to_filename(disk_name, template)
  template.hardware.disks.select { |x| x if x.device_name == disk_name }.first.filename
end

def wait_ip(vm)
  ip = ''
  30.times do 
    unless vm.ipaddresses.any?
      vm.ext_management_system.refresh
      sleep(10.seconds)
    else
      return vm.ipaddresses.first
    end
  end
  ip
end

def save_vm_configuration(vm)
  configuration = {}
  configuration[:disks] = {}
  configuration[:nics] = {}
  configuration[:vm_name] = vm.name
  vm.disks.each do |disk|
    storage = $evm.vmdb(:Storage).find(disk.storage_id).name
    configuration[:disks][disk.device_name] = {}
    configuration[:disks][disk.device_name][:storage_type] = $evm.vmdb(:Storage).find(disk.storage_id).tags.select { |s| s if s.match?(/disk_type/) }.first.split('/').last
  end
  vm.hardware.nics.each do |nic|
    configuration[:nics][nic.device_name] = {}
    configuration[:nics][nic.device_name][:id] = nic.uid_ems
    configuration[:nics][nic.device_name][:mac] = nic.address
  end
  
  configuration
end

def change_vm_configuration(restore)
  configuration = JSON.parse(restore.backup.first.configuration)
  flag = false
  count = 0
  nics = configuration["nics"]
  vm_name = configuration["vm_name"]
  vm = get_vm_from_vmdb(restore.new_vm_uuid)
  connection = vm.ext_management_system.connect
  begin
    connection.system_service.vms_service.vm_service(restore.new_vm_uuid).nics_service.list.each do |nic|
      original_mac = nics[nic.name.to_s]["mac"]
      new_mac = connection.system_service.vms_service.vm_service(restore.new_vm_uuid).nics_service.list.first.mac.address
      temp_addr = get_dummy_mac
      
      original_uid = $evm.vmdb(:Vm).find_by(:name => vm_name).uid_ems 
      original_nic_id  = $evm.vmdb(:Vm).find_by(:name => vm_name).nics.first.uid_ems
 
      connection.system_service.vms_service.vm_service(original_uid).nics_service.nic_service(original_nic_id).update(:mac => {:address => temp_addr})
      connection.system_service.vms_service.vm_service(restore.new_vm_uuid).nics_service.nic_service(nic.id).update(:mac => {:address => original_mac})
      connection.system_service.vms_service.vm_service(original_uid).nics_service.nic_service(original_nic_id).update(:mac => {:address => new_mac})
      flag = true
    end
  rescue StandardError
    vm = get_vm_from_vmdb(restore.new_vm_uuid)
    retry if (count += 1) < 100
    exit MIQ_ERROR
  end
  final_restoring(restore, vm) if flag
end

def get_dummy_mac
  (1..6).map { "%0.2X" % rand(256) }.join(":").downcase
end

def fix_network_clone(parent_vm_id, new_vm_id)
  parent_vm = $evm.vmdb(:Vm).find(parent_vm_id)
  new_vm = $evm.vmdb(:Vm).find(new_vm_id)
  # even if hostname exists, we should use a new one
  hostname = generate_hostname
  $evm.root['hostname'] = hostname
  begin
    lan_name = parent_vm.hardware.nics[0].lan.name
    mac = new_vm.mac_addresses[0]
    raise StandardError, 'no mac address' unless mac
  rescue StandardError
    $evm.log(:info, "No hardware info in vm object, retry with ovirt data..")
    connection = new_vm.ext_management_system.connect
    vm_service = connection.system_service.vms_service.vm_service(new_vm.uid_ems)
    nic_uuid = vm_service.nics_service.list.first.id
    vnic_profile_id = vm_service.nics_service.nic_service(nic_uuid).get.vnic_profile.id
    lan_name = connection.system_service.vnic_profiles_service.list.select { |x| x.id == vnic_profile_id }.first.name
    mac = vm_service.nics_service.list.first.mac.address
  end
  network_parameters = get_dhcp_addr_lib(lan_name)
  subnet_ip_addr = network_parameters['network']
  start_ip = network_parameters['from']
  end_ip = network_parameters['to']
  ip_range = "from=" + start_ip + "&to=" + end_ip
  $evm.instantiate("/Integration/Foreman/Creds/Default")
  $evm.log(:info, "DBG clone network params: #{mac} lan_name #{lan_name} hostname #{hostname} subnet_ip_addr #{subnet_ip_addr} ip_range #{ip_range}")
  vm_registration_lib(hostname, lan_name, subnet_ip_addr, ip_range, mac)
end

def add_vm_to_service(parent_vm_id, new_vm_id)
  parent_service = $evm.vmdb(:Vm).find(parent_vm_id).service
  new_service_id = parent_service.custom_get(:clone_service_id)
  new_service = $evm.vmdb(:Service).find(new_service_id)
  owner = $evm.vmdb(:user).find_by(:id => parent_service.evm_owner_id)
  vm = $evm.vmdb(:VmOrTemplate).find(new_vm_id)
  vm&.add_to_service(new_service)
  new_service.owner = owner
  new_service.group = owner.current_group
  vm.owner = owner
  vm.group = owner.current_group
  vm.start
  $evm.log(:info, "vm #{vm.id} is added to service #{new_service.name} - #{new_service.id}")
  vm
end

def clearing_after_cloning(snapshot_uuid, vm)
  snapshot = get_snapshot_from_vmdb(snapshot_uuid)
  snapshot.remove
  vm.custom_set(:cloning, nil)
  vm.ext_management_system.refresh

end

def final_restoring(restore, vm)
  connection = vm.ext_management_system.connect
  connection.system_service.vms_service.vm_service(vm.uid_ems).start
  connection.system_service.vms_service.vm_service(restore.backup.first.service.first.vms.first.uid_ems).stop
  vm.tags.push(restore.backup.first.service.first.vms.first.tags)
  vm.group = restore.backup.first.service.first.vms.first.owner.current_group
  vm.owner = restore.backup.first.service.first.vms.first.owner
  restore.backup.first.service.first.vms.first.remove_from_service
  vm.add_to_service(restore.backup.first.service.first)
  restore.update!(:status => 'restored')
end

# In this part we try to get record about vm/snapshot/template from DB and if record doesn't exist - waiting while Refresher add it to DB
# 10 times and 5 second - random numbers :)
def get_snapshot_from_vmdb(snapshot_uuid)
  snapshot = $evm.vmdb(:Snapshot).find_by(:description => snapshot_uuid)
  10.times do
    unless snapshot
    sleep 5
    snapshot = $evm.vmdb(:Snapshot).find_by(:description => snapshot_uuid)
    end
  end
  snapshot
end

def get_template_from_vmdb(template_uuid)
  template = $evm.vmdb(:VmOrTemplate).find_by(:uid_ems => template_uuid)
  10.times do
    break if template
    sleep 5
    template = $evm.vmdb(:VmOrTemplate).find_by(:uid_ems => template_uuid)
  end
  template
end

def get_vm_from_vmdb(vm_uuid)
  vm = $evm.vmdb(:VmOrTemplate).find_by(:uid_ems => vm_uuid)
  10.times do
    break if vm
    sleep 5
    vm = $evm.vmdb(:VmOrTemplate).find_by(:uid_ems => vm_uuid)
  end
  vm
end

def active_backups_count(service)
  backups_in_processing = []
  service.generic_objects.each do |backup|
    if backup.name.start_with?("bkp_") && !backup.terminated && !(backup.status.eql?("ready") || backup.status.eql?("error"))
      backups_in_processing.push(backup)
    end
  end
  backups_in_processing.length
end

def lock_other_backups(service)
  service.generic_objects.each do |go|
    if go.name.start_with?("bkp_") && !go.terminated && go.status.eql?("ready")
      go.update!(:status => 'locked')
    end
  end
end

def unlock_other_backups(service)
  service.generic_objects.each do |go|
    if go.name.start_with?("bkp_") && !go.terminated && go.status.eql?("locked")
      go.update!(:status => 'ready')
    end
  end
end

def check_orphaned(uid_ems)
  ems_id_nil = $evm.vmdb(:VmOrTemplate).find_by(:uid_ems => uid_ems).ext_management_system.nil?
  storage_id_nil = $evm.vmdb(:VmOrTemplate).find_by(:uid_ems => uid_ems).storage_id.nil?
  ems_id_nil && !storage_id_nil
end

def check_archived(uid_ems)
  ems_id_nil = $evm.vmdb(:VmOrTemplate).find_by(:uid_ems => uid_ems).ext_management_system.nil?
  storage_id_nil = $evm.vmdb(:VmOrTemplate).find_by(:uid_ems => uid_ems).storage_id.nil?
  ems_id_nil && storage_id_nil
end

def get_snapshot_description(vm_name)
  vm_name.slice!("cld_cl")
  "clone" + vm_name
end
