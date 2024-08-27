module Backups
  module Automate
    module GenericObject
      module Methods
        module Redhat
          class UndoRestoredVm
            def initialize(handle = $evm)
              @handle = handle
              @backup = @handle.vmdb(:GenericObject).find(@handle.root['backup_id'])
            end

            def main
              @handle.log(:info, "Undoing restored VM from backup #{@backup.name} " \
                                 "in service #{@backup.service.first.name}")
              undo_restored_vm
              @handle.log(:info, 'End undoing')
            end

            private

            def undo_restored_vm
              original_vm_id = original_vm.id
              new_vm_id = new_vm.id

              last_restore.update!(status: 'undoing_restored_vm')
              last_backup.update!(status: 'undoing')

              change_mac_addresses
              remove_new_vm
              restore_original_vm

              last_restore.update!(status: 'undo_restored_vm')
              last_backup.update!(status: 'ready')

              unlock_other_service_backups(last_restore.service.first)
              update_vm_backup_schedules(original_vm_id, new_vm_id)
            end

            def change_mac_addresses
              connection = establish_connection(original_vm)
              new_vm_connection = connect_to_vm_service(connection, last_restore.new_vm_uuid)
              original_vm_connection = connect_to_vm_service(connection, last_restore.original_vm_uuid)

              new_vm_connection.shutdown
              original_vm_connection.shutdown

              sleep 10
              change_vm_networks(last_restore, new_vm, original_vm_connection, new_vm_connection)
            end

            def remove_new_vm
              return unless new_vm

              connection = establish_connection(new_vm)
              connection.system_service.vms_service.vm_service(new_vm.uid_ems).shutdown
              sleep 25

              begin
                remove_dns_records(@backup.service.first, new_vm)
              	connection.system_service.vms_service.vm_service(new_vm.uid_ems).remove
              	new_vm.remove_from_vmdb
              rescue OvirtSDK4::Error
                sleep 15
                @handle.log(:info, "Can't remove restored vm. Retrying...")
                retry
              end
            end

            def restore_original_vm
              original_vm.add_to_service(last_restore.service.first)
              connection = establish_connection(original_vm)
              original_vm.ext_management_system.try(:network_manager)&.refresh
              sleep 25
              connect_to_vm_service(connection, last_restore.original_vm_uuid).start
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

Backups::Automate::GenericObject::Methods::Redhat::UndoRestoredVm.new.main
