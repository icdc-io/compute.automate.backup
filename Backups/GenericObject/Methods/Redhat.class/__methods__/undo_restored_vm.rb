require 'ovirtsdk4'

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
              last_restore.update!(status: 'undoing_restored_vm')
              last_backup.update!(status: 'undoing')
              
              # 1. shutdown vms
              # 2. detach disks
              # 3. swtich disks between vms
              # 4. remove new vm
              shutdown_vm(last_restore.original_vm_uuid)
              shutdown_vm(last_restore.new_vm_uuid)
              
              disconnect_disks(last_restore.original_vm_uuid)
              disconnect_disks(last_restore.new_vm_uuid)
              
              connect_disks(last_restore.original_disks_map, last_restore.original_vm_uuid)
              connect_disks(last_restore.backup_disks_map, last_restore.new_vm_uuid)
              
              remove_vm(last_restore.new_vm_uuid)

              last_restore.update!(status: 'undo_restored_vm')
              last_backup.update!(status: 'ready')

              unlock_other_service_backups(last_restore.service.first)
            end
            
            def shutdown_vm(vm_uid)
              connection = $evm.vmdb(:VmOrTemplate).find_by(uid_ems: vm_uid).ext_management_system.connect
              connection.system_service.vms_service.vm_service(vm_uid).shutdown
              sleep(10)
            end
            
            def remove_vm(vm_uid)
			  connection = $evm.vmdb(:VmOrTemplate).find_by(uid_ems: vm_uid).ext_management_system.connect
              connection.system_service.vms_service.vm_service(vm_uid).remove
            end

            def last_restore
              @last_restore ||= Restore.find_objects(backup_name: @backup.name).max_by(&:created_at)
            end

            def last_backup
              @last_backup ||= last_restore.backup.first
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Methods::Redhat::UndoRestoredVm.new.main
