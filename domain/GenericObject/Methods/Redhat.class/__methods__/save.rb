backup_id = $evm.root["backup_id"]
backup_name = $evm.vmdb(:GenericObject).find(backup_id).name
restore = Restore.find_objects(:backup_name => backup_name).sort_by(&:created_at).last
backup = restore.backup.first
vm_to_restore = $evm.vmdb(:VmOrTemplate).find_by(:uid_ems => restore.original_vm_uuid)
connection = establish_connection(vm_to_restore)
connection.system_service.vms_service.vm_service(vm_to_restore.uid_ems).remove
vm_to_restore.remove_from_vmdb
connection.system_service.vms_service.vm_service(restore.service.first.vms.first.uid_ems).update(:name => JSON.parse(backup.configuration)["vm_name"])
restore.update!(:status => "save_restored_vm")
backup.update!(:status => "ready")
unlock_other_backups(backup.service.first)
