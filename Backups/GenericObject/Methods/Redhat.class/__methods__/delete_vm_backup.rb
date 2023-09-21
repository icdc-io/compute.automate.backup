backup_id = $evm.root['backup_id']
backup = $evm.vmdb(:GenericObject).find(backup_id)
exit MIQ_OK if backup.terminated

if backup.template_id.nil?
  exit MIQ_OK if backup.service.first.vms.first.nil?
  # TODO: if there is no VM in service may be need to take default ext_management_system
  #       or take service template which used to deploy this ervice
  connection = establish_connection(backup.service.first.vms.first) # take connection by first vm
  template = connection.system_service.templates_service.list.select { |d| d.name == backup.name }
  exit MIQ_OK if template.first.nil?
  uid = template.first.id 
  begin
    remove_template(connection, uid, backup)
  rescue StandardError => e
    $evm.log(:error, "Attempt to remove template #{e.message}")
  end
else
  begin
    template = $evm.vmdb(:VmOrTemplate).find(backup.template_id)
  rescue StandardError
    $evm.log(:info, "Template with id [#{backup.template_id}] doesn`t exist.")
    backup.update_attributes!(:terminated => "true")
    exit MIQ_OK
  end
  connection = establish_connection(template) # take connection by template

  is_archived = check_archived(template.uid_ems)
  is_orphaned = check_orphaned(template.uid_ems)

  exit MIQ_OK if is_orphaned || is_archived

  begin
    remove_template(connection, template.uid_ems, backup)
  rescue StandardError => e
    $evm.log(:error, "Attempt to remove template #{e.message}")
  end
end
