event_msg = $evm.vmdb(:EventStream).find($evm.root['event_id']).message
rematch = event_msg.match(/^Snapshot '([a-z0-9\-]+)'/)
exit MIQ_OK unless rematch
snapshot_uuid = rematch[1] if rematch
exit MIQ_ERROR unless rematch
backup = Backup.find_objects(:snapshot_uuid => snapshot_uuid).first
exit MIQ_OK unless backup
begin
  snapshot = get_snapshot_from_vmdb(snapshot_uuid)
  backup.update!(:status => "created_snapshot") # For future, mb we need also one step in creation backup
  backup.update!(:status => "creating_template")
  connection =  establish_connection(backup.service.first.vms.first)
  create_template(connection, snapshot, backup)
rescue StandardError
  backup.update!(:error => true)
  exit MIQ_ABORT
end
