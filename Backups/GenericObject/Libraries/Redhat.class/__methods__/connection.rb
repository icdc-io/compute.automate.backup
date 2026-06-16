#
# Description: connection lib that is used for backups
#

def establish_connection(vm_or_template)
  ems ||= vm_or_template&.ext_management_system
  ems ||= vm_or_template&.service&.service_template&.service_resources&.first&.resource&.source&.ext_management_system
  ems ||= $evm.vmdb(:ExtManagementSystem).find_by(type: 'ManageIQ::Providers::Redhat::InfraManager')

  ems.connect
end

def connect_to_vm_service(connection, uid_ems)
  connection.system_service.vms_service.vm_service(uid_ems)
end
