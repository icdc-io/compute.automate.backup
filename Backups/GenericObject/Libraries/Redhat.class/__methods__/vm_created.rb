event = $evm.vmdb(:EventStream).find($evm.root['event_id'])
uid = event.full_data["vm"]["id"]
event_msg = event.message
rematch = event_msg.match(/^VM (rst_.+) creation has been completed./) # || event_msg.match(/^VM (dev_.+) creation has been completed./)

vm_name = rematch[1] if rematch
exit MIQ_ERROR unless vm_name
if rematch
  $evm.log(:info, "in restore branch")
  restore = Restore.find_objects(:name => vm_name).sort_by(&:created_at).last
  restore.update!(:status => "vm_created", :new_vm_uuid => uid)
  change_vm_configuration(restore)
  restore.backup.first.update!(:status => "restored")
end
