backup_id = $evm.root["backup_id"]
backup_name = $evm.vmdb(:GenericObject).find(backup_id).name
restore = Restore.find_objects(:backup_name => backup_name).sort_by(&:created_at).last
restore.update!(:status => "unding_restored_vm")
backup = restore.backup.first
connection = establish_connection( backup.service.first.vms.first)
connection.system_service.vms_service.vm_service(restore.service.first.vms.first.uid_ems).shutdown
sleep 25
begin
  connection.system_service.vms_service.vm_service(restore.service.first.vms.first.uid_ems).remove
  restore.service.first.vms.first.remove_from_vmdb
  old_vm = get_vm_from_vmdb(restore.original_vm_uuid)
  old_vm.add_to_service(restore.service.first)
  backup.update!(:status => "ready")
  unlock_other_backups(restore.service.first)
rescue StandardError
  sleep 25
  retry
end
