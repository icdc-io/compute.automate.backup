event = $evm.vmdb(:EventStream).find($evm.root['event_id'])
uid = event.full_data["vm"]["id"]
event_msg = event.message
rematch = event_msg.match(/^VM (rst_.+) creation has been completed./) # || event_msg.match(/^VM (dev_.+) creation has been completed./)
rematch_cl = event_msg.match(/^VM (cld_cl-.+) creation has been completed./)

vm_name = rematch[1] if rematch
vm_name = rematch_cl[1] if rematch_cl
exit MIQ_ERROR unless vm_name
if rematch
  $evm.log(:info, "in restore branch")
  restore = Restore.find_objects(:name => vm_name).sort_by(&:created_at).last
  restore.update!(:status => "vm_created", :new_vm_uuid => uid)
  change_vm_configuration(restore)
  restore.backup.first.update!(:status => "restored")
elsif rematch_cl
  $evm.log(:info, "in clone branch")
  parent_vm_id = vm_name[/\-[0-9]+\-/].delete("-")
  parent_vm = $evm.vmdb(:Vm).find(parent_vm_id)
  vm = get_vm_from_vmdb(uid)
  vm_updated = add_vm_to_service(parent_vm_id, vm.id)
  snapshot_name = get_snapshot_description(vm_name)
  clearing_after_cloning(snapshot_name, parent_vm)
  $evm.instantiate("Service/Email/Email/Email")
  send_email(parent_vm, vm_updated)
end
