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
