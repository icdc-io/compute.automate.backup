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
