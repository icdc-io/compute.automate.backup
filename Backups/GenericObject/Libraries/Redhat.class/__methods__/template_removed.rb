event_msg = $evm.vmdb(:EventStream).find($evm.root['event_id']).message
rematch = event_msg.match(/^Removal of Template (bkp_.+) has been completed./)
template_name = rematch[1] if rematch
exit MIQ_OK unless template_name
backup = Backup.find_objects(:name => template_name, :status => "deleting_template").sort_by(&:created_at).last
backup.update!(:status => "deleted", :terminated => true)
