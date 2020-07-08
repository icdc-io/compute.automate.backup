$evm.log(:info,"DBG NINA in create_vm_backup")
if $evm.root["service_id"]
  service_id = $evm.root["service_id"]
elsif $evm.root["vm_id"]
 service_id = $evm.vmdb(:VmOrTemplate).find($evm.root["vm_id"]).direct_service.id
end

service = $evm.vmdb(:Service).find(service_id)
#service = $evm.vmdb(:Service).find(26000000000021)
service ||= $evm.root["service"]
exit MIQ_OK if active_backups_count(service).positive?
description = $evm.root['backup_name'] if $evm.root['backup_name']
service.vms.each do |vm|
  new_backup = Backup.create_object(:name          => "bkp_#{vm.id}_#{Time.now.strftime('%Y%m%d-%H%M')}", # rubocop:disable Rails/TimeZone
                                    :status        => "not_started",
                                    :error         => false,
                                    :snapshot_uuid => nil,
                                    :template_id   => nil,
                                    :terminated    => false,
                                    :configuration => save_vm_configuration(vm).to_json,
                                    :description   => description.to_s)
  new_backup.service = [vm.direct_service]
  new_backup.add_to_service(vm.direct_service)
  new_backup.save!
  create_snapshot(vm, new_backup)
end
