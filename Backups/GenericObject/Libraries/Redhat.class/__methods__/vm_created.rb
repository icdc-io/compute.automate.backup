module Backups
  module Automate
    module GenericObject
      module Libraries
        module Redhat
          class VmCreated
            def initialize(handle = $evm)
              @handle = handle
              @event = @handle.vmdb(:EventStream).find(@handle.root['event_id'])
            end

            def main
              @handle.log(:info, 'Start vm_created method')
              vm_created
              @handle.log(:info, 'End method')
            end

            private

            def vm_created
              uid = @event.full_data['vm']['id']
              event_msg = @event.message

              rematch = event_msg.match(/^VM (rst_#{ENV.fetch('LOCATION_NAME')}_.+) creation has been completed./) # || event_msg.match(/^VM (dev_.+) creation has been completed./)
              vm_name = rematch[1] if rematch
              exit MIQ_ERROR unless vm_name
              return unless rematch
              restore = Restore.find_objects(name: vm_name).max_by(&:created_at)
              
              restore.update!(status: 'vm_created', new_vm_uuid: uid)
              
              $evm.log(:info, "[Restore #{restore.id}]: stopping vms") 
              stop_vms(restore)
              
              $evm.log(:info, "[vm_created] save original disk_map #{restore.original_vm_uuid}")
              restore.update!(original_disks_map: disks_map(restore.original_vm_uuid))
              
              $evm.log(:info, "[vm_created] save backup disk_map #{restore.new_vm_uuid}")
              restore.update!(backup_disks_map: disks_map(restore.new_vm_uuid))
              
              $evm.log(:info, "[vm_created] disconnect disks #{restore.original_vm_uuid}")
              disconnect_disks(restore.original_vm_uuid)
              
              $evm.log(:info, "[vm_created] disconnect disks #{restore.new_vm_uuid}")
              disconnect_disks(restore.new_vm_uuid)              

			  $evm.log(:info, "[vm_created] connect disks from original vm to restored #{restore.original_vm_uuid}")
              connect_disks(restore.backup_disks_map, restore.original_vm_uuid)

			  $evm.log(:info, "[vm_created] connect disks from restored vm to original #{restore.new_vm_uuid}")
              connect_disks(restore.original_disks_map, restore.new_vm_uuid)
              restore.backup.first.update!(status: 'restored')
            end
            
            def stop_vms(restore)
              $evm.log(:info, "debug ae_state_retries #{$evm.root['ae_state_retries']}")
              db_vm = $evm.vmdb(:VmOrTemplate).find_by(uid_ems: restore.original_vm_uuid)
              sdk_vms_service = db_vm.ext_management_system.connect.system_service.vms_service
              retry_needed = false
              
              $evm.log(:info, "checking original vm state")
              sdk_vm = sdk_vms_service.vm_service(restore.original_vm_uuid)
              unless sdk_vm.get.status == "down"
                sdk_vm.shutdown
                retry_needed = true
              end
              
              $evm.log(:info, "checking new vm state")
              sdk_new_vm = sdk_vms_service.vm_service(restore.new_vm_uuid)
              unless sdk_new_vm.get.status == "down"
                sdk_new_vm.shutdown
                retry_needed = true
              end
              
              if retry_needed
                $evm.root['ae_result']         = 'retry'
				$evm.root['ae_retry_interval'] = '1.minute'
                exit MIQ_OK
              end
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Libraries::Redhat::VmCreated.new.main