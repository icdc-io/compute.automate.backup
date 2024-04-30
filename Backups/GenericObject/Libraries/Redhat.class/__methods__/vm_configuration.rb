#
# Description: vm_configuration lib that is used for backup
#

def vm_configuration(vm)
  configuration = {}
  configuration[:disks] = {}
  configuration[:nics] = {}
  configuration[:vm_name] = vm.name
  configuration[:disks] = vm_disks(vm)
  configuration[:nics] = vm_nics(vm)
  configuration
end

def vm_disks(vm)
  disks = {}

  vm.disks.each do |disk|
    storage = $evm.vmdb(:Storage).find(disk.storage_id)
    storage_type = storage.tags.find { |tag| tag if tag.include?('storage_type') }.split('/').last

    disks[disk.device_name] = {}
    disks[disk.device_name][:storage_type] = storage_type
  end

  disks
end

def vm_nics(vm)
  nics = {}

  vm.hardware.nics.each do |nic|
    nics[nic.device_name] = {}
    nics[nic.device_name][:id] = nic.uid_ems
    nics[nic.device_name][:mac] = nic.address
  end

  nics
end

def change_vm_configuration(restore)
  original_vm = get_vm_or_template_from_vmdb(restore.original_vm_uuid)

  connection = establish_connection(original_vm)
  new_vm_connection = connect_to_vm_service(connection, restore.new_vm_uuid)
  original_vm_connection = connect_to_vm_service(connection, restore.original_vm_uuid)

  new_vm_connection.shutdown
  original_vm_connection.shutdown

  sleep(10)

  final_restore_needed = change_vm_networks(restore, original_vm, new_vm_connection, original_vm_connection)
  final_restoring(restore) if final_restore_needed
end

def change_vm_networks(restore, original_vm, new_vm_connection, original_vm_connection)
  final_restore = false
  nics = JSON.parse(restore.backup.first.configuration)['nics']

  new_vm_nics = new_vm_connection.nics_service
  original_vm_nics = original_vm_connection.nics_service

  new_vm_nics.list.each do |nic|
    original_mac = nics[nic.name.to_s]['mac']
    new_mac = new_vm_nics.list.first.mac.address

    original_nic_uid = original_vm.nics.first.uid_ems

    10.times do
      original_vm_nics.nic_service(original_nic_uid).update(mac: { address: dummy_mac }) # set temporary mac
      break
    rescue => error
      $evm.log(:error, "Error setting dummy mac:")
      $evm.log(:error, error.message)
      exit MIQ_ERROR unless error.message =~ /4\d\d/
      $evm.log(:error, "Trying another mac.")
    end
    
    new_vm_nics.nic_service(nic.id).update(mac: { address: original_mac })
    original_vm_nics.nic_service(original_nic_uid).update(mac: { address: new_mac })

    final_restore = true
  end

  final_restore
end

def dummy_mac
  (1..6).map { '%0.2X' % rand(256) }.join(':').downcase
end

def find_vm_ip(vm)
  vm_name = vm.name
  vm_ip = ips(vm).first

  # it may need some time to assign ip and hostname values to vm, so we need to wait
  # there also can be case when after the time has expired, the hostname may not be assigned
  20.times do
    break $evm.log(:info, "Vm #{vm_name} ip: '#{vm_ip}'") if vm_ip

    sleep 20
    $evm.log(:info, "Vm #{vm_name} hasn't got ip. Retrying...")
    vm.ext_management_system.try(:network_manager)&.refresh
    vm_ip = ips(vm.reload).first
  end
end

def final_restoring(restore)
  new_vm = get_vm_or_template_from_vmdb(restore.new_vm_uuid)
  original_vm = get_vm_or_template_from_vmdb(restore.original_vm_uuid)

  connection = establish_connection(new_vm)
  connect_to_vm_service(connection, new_vm.uid_ems).start
  connect_to_vm_service(connection, original_vm.uid_ems).stop

  new_vm.tags.push(original_vm.tags)
  new_vm.owner = original_vm.owner
  new_vm.group = original_vm.owner.current_group

  original_vm.remove_from_service
  new_vm.add_to_service(restore.service.first)
  
  restore.backup.first.update!(status: 'updating_dns')
  sleep 20
  find_vm_ip(new_vm)

  clone_dns_records(restore.service.first, original_vm, new_vm)
  clone_security_groups(original_vm, new_vm)
  restore.update!(status: 'restored')
end
