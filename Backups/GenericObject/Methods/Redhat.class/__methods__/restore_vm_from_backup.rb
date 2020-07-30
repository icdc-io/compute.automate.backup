#backup_id = '26000000000009' 
$evm.root['backup_id']
backup = $evm.vmdb(:GenericObject).find(backup_id)
exit MIQ_OK if active_backups_count(backup.service.first).positive?
lock_other_backups(backup.service.first)
new_restore = Restore.create_object(:name             => "rst_" + backup.service.first.vms.first.name[4..-1],
                                    :status           => "restoring",
                                    :error            => false,
                                    :original_vm_uuid => backup.service.first.vms.first.uid_ems,
                                    :backup_name      => backup.name,
                                    :new_vm_uuid      => nil)
new_restore.service = [backup.service.first]
new_restore.backup = [backup]
new_restore.add_to_service(backup.service.first)
new_restore.save!
connection =  backup.service.first.vms.first.ext_management_system.connect
create_vm_from_template(connection, new_restore)
