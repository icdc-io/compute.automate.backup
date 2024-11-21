def get_api_connection(vm)
  vm.ext_management_system.connect.system_service
end

def disks_map(vm_uid)
  vm = $evm.vmdb(:VmOrTemplate).find_by(uid_ems: vm_uid)
  connection = get_api_connection(vm)
  connection.vms_service.vm_service(vm.uid_ems).shutdown
  sleep(10)
  da_list = connection.vms_service.vm_service(vm.uid_ems).disk_attachments_service.list
  
  da_list.map do |da|
    d = connection.disks_service.disk_service(da.disk.id).get

	{
      bootable: da.bootable,
      interface: 'virtio_scsi',
      active: true,
      disk: {
        id: da.disk.id,
        provisioned_size: d.provisioned_size,
        format: d.format
      }
    }
  end.to_json
end

def disconnect_disks(vm_uid)
  vm = $evm.vmdb(:VmOrTemplate).find_by(uid_ems: vm_uid)
  connection = get_api_connection(vm)
  da_list = connection.vms_service.vm_service(vm.uid_ems).disk_attachments_service.list
  
  da_list.each do |da|
    $evm.log(:info, "[BACKUP configuration] disconnect disk #{da.disk.id} from #{vm.name}")
    connection.vms_service.vm_service(vm.uid_ems).disk_attachments_service.attachment_service(da.id).remove
  end
end

def connect_disks(disks, vm_uid)
  vm = $evm.vmdb(:VmOrTemplate).find_by(uid_ems: vm_uid)
  connection = get_api_connection(vm)
  disks = JSON.parse(disks)
  
  disks.each do |d|
    $evm.log(:info, "[BACKUP configuration] connect disk #{d} to #{vm.name}")
    connection.vms_service.vm_service(vm.uid_ems).disk_attachments_service.add(OvirtSDK4::DiskAttachment.new(d.deep_symbolize_keys))
  end
  
end
