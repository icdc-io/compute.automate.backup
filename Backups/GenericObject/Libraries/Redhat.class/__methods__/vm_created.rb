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

              @handle.log(:info, 'in restore branch')
              restore = Restore.find_objects(name: vm_name).max_by(&:created_at)
              restore.update!(status: 'vm_created', new_vm_uuid: uid)
              
              $evm.log(:info, "[restore backup] save original disk_map #{restore.original_vm_uuid}")
              restore.update!(original_disks_map: disks_map(restore.original_vm_uuid))
              
              $evm.log(:info, "[restore backup] save backup disk_map #{restore.new_vm_uuid}")
              restore.update!(backup_disks_map: disks_map(restore.new_vm_uuid))
              
              $evm.log(:info, "[restore backup] disconnect disks #{restore.original_vm_uuid}")
              disconnect_disks(restore.original_vm_uuid)
              
              $evm.log(:info, "[restore backup] disconnect disks #{restore.new_vm_uuid}")
              disconnect_disks(restore.new_vm_uuid)              

			  $evm.log(:info, "[restore backup] connect disks #{restore.original_vm_uuid}")
              connect_disks(restore.backup_disks_map, restore.original_vm_uuid)
              
			  $evm.log(:info, "[restore backup] connect disks #{restore.new_vm_uuid}")
              connect_disks(restore.original_disks_map, restore.new_vm_uuid)
                            
              restore.backup.first.update!(status: 'restored')
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Libraries::Redhat::VmCreated.new.main
