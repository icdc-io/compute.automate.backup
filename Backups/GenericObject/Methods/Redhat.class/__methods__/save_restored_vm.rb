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
              @handle.log(:info, "Saving restored VM from backup #{@backup.name} " \
                                 "in service #{@backup.service.first.name}")
              save_restored_vm
              @handle.log(:info, 'End saving')
            end

            private

            def save_restored_vm
              original_vm_id = original_vm.id
              new_vm_id = new_vm.id

              last_restore.update!(status: 'saving_restored_vm')

              remove_original_vm
              save_new_vm

              last_restore.update!(status: 'save_restored_vm')
              last_backup.update!(status: 'ready')

              unlock_other_service_backups(last_backup.service.first)
              update_vm_backup_schedules(new_vm_id, original_vm_id)
            end

            def remove_original_vm
              return unless original_vm

              connection = establish_connection(original_vm)
              connection.system_service.vms_service.vm_service(original_vm.uid_ems).shutdown
              sleep 25

              begin
              	connection.system_service.vms_service.vm_service(original_vm.uid_ems).remove
              	original_vm.remove_from_vmdb
              rescue OvirtSDK4::Error
                sleep 15
                retry
              end
            end

            def save_new_vm
              new_vm_name = JSON.parse(last_backup.configuration)['vm_name']
              connection = establish_connection(new_vm)

              begin
                connection.system_service.vms_service.vm_service(new_vm.uid_ems).update(name: new_vm_name)
              rescue OvirtSDK4::Error
                sleep 15 # TODO: maybe this is error?
                retry
              end
            end

            def last_restore
              @last_restore ||= Restore.find_objects(backup_name: @backup.name).max_by(&:created_at)
            end

            def last_backup
              @last_backup ||= last_restore.backup.first
            end

            def new_vm
              @new_vm ||= get_vm_or_template_from_vmdb(last_restore.new_vm_uuid)
            end
            
            def original_vm
              @original_vm ||= get_vm_or_template_from_vmdb(last_restore.original_vm_uuid)
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Methods::Redhat::SaveRestoredVm.new.main
