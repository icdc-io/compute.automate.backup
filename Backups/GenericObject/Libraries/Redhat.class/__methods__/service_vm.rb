#
# Description: service_vm lib that is used for backup
#

def add_vm_to_service(parent_vm_id, new_vm_id)
  parent_service = $evm.vmdb(:Vm).find(parent_vm_id).service

  owner = parent_service.evm_owner
  owner_group = owner.current_group

  new_service = $evm.vmdb(:Service).find(parent_service.custom_get(:clone_service_id))
  new_service.owner = owner
  new_service.group = owner_group

  new_vm = $evm.vmdb(:VmOrTemplate).find(new_vm_id)
  new_vm.add_to_service(new_service)
  new_vm.owner = owner
  new_vm.group = owner_group
  new_vm.start

  $evm.log(:info, "vm #{new_vm.id} is added to service #{new_service.name} - #{new_service.id}")
  new_vm
end
