module Backups
  module Automate
    module GenericObject
      module Methods
        module Redhat
          class SaveRestoredVm
            def initialize(handle = $evm)
              @handle = handle
              @backup = @handle.vmdb(:GenericObject).find(@handle.root['backup_id'])
            end

            def main
              return unless @backup.status == 'restored'
              
              @handle.log(:info, "Saving restored VM from backup #{@backup.name} " \
                                 "in service #{@backup.service.first.name}")
              save_restored_vm
              @handle.log(:info, 'End saving')
            end

            private

            def save_restored_vm
              last_restore.update!(status: 'saving_restored_vm')
              @backup.update!(status: 'saving')

			  api = connection(last_restore.new_vm_uuid)
              api.vms_service.vm_service(last_restore.new_vm_uuid).remove

              last_restore.update!(status: 'save_restored_vm')
              @backup.update!(status: 'ready')

              unlock_other_service_backups(@backup.service.first)
            end
            
                        
            def last_restore
              @last_restore ||= Restore.find_objects(backup_name: @backup.name).max_by(&:created_at)
            end
            
            def connection(vm_uid)
              $evm.vmdb(:VmOrTemplate).find_by(uid_ems: vm_uid).ext_management_system.connect.system_service
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Methods::Redhat::SaveRestoredVm.new.main
