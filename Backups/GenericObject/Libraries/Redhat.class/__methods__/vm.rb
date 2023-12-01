#
# Description: vm lib that is used for backup
#

def check_orphaned(uid_ems)
  vm = $evm.vmdb(:VmOrTemplate).find_by(uid_ems: uid_ems)
  vm.ext_management_system.nil? && !vm.storage_id.nil?
end

def check_archived(uid_ems)
  vm = $evm.vmdb(:VmOrTemplate).find_by(uid_ems: uid_ems)
  vm.ext_management_system.nil? && vm.storage_id.nil?
end

def update_vm_backup_schedules(new_vm_id, old_vm_id)
  schedules = $evm.vmdb(:MiqSchedule).where(sched_action_for_backup_vm(old_vm_id))
  return unless schedules.present?

  schedules.each { |schedule| schedule.object_send(:update, sched_action_for_backup_vm(new_vm_id)) }
end

def sched_action_for_backup_vm(vm_id)
  { sched_action: { method: "service_backup", options: { vm_id: vm_id.to_s } } }
end
