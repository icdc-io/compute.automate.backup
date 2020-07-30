event = $evm.vmdb(:EventStream).find($evm.root['event_id'])
# event = $evm.vmdb(:EmsEvent).find(26000000125620)  
rematch = event.message.match(/^Creation of Template (bkp_.+) from VM/)
template_uuid = event.full_data["template"]["id"] if rematch
template = get_template_from_vmdb(template_uuid)
exit MIQ_OK unless template
begin
  backup = Backup.find_objects(:name => template.name).first
  backup.template = [template]
  backup.update!(:status => "created_template", :template_id => template.id)
  backup.update!(:status => "deleting_snapshot")
  $evm.vmdb(:Snapshot).find_by(:description => backup.snapshot_uuid).remove
  backup.update!(:status => "deleted_snapshot")
  backup.update!(:status => "ready")
rescue StandardError
  backup.update!(:error => true)
end
