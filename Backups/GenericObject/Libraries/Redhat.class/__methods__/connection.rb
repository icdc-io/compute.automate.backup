#
# Description: connection lib that is used for backups
#

require 'ovirtsdk4'

def establish_connection(vm_or_template)
  vm_or_template.ext_management_system.connect
end

def connect_to_vm_service(connection, uid_ems)
  connection.system_service.vms_service.vm_service(uid_ems)
end
