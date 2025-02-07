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
              
              $evm.log(:info, "[Undo backup] stop vms for sure")
              stop_vms(last_restore)

              $evm.log(:info, "[Undo backup] disconnect disks from #{last_restore.original_vm_uuid}")
              disconnect_disks(last_restore.original_vm_uuid)
              $evm.log(:info, "[Undo backup] disconnect disks from #{last_restore.new_vm_uuid}")
              disconnect_disks(last_restore.new_vm_uuid)
              
              $evm.log(:info, "[Undo backup] connect disks to #{last_restore.original_vm_uuid}")
              connect_disks(last_restore.original_disks_map, last_restore.original_vm_uuid)
              $evm.log(:info, "[Undo backup] connect disks to #{last_restore.new_vm_uuid}")
              connect_disks(last_restore.backup_disks_map, last_restore.new_vm_uuid)
              
              remove_vm(last_restore.new_vm_uuid)

              last_restore.update!(status: 'undo_restored_vm')
              last_backup.update!(status: 'ready')

              unlock_other_service_backups(last_restore.service.first)
            end
            
            def remove_vm(vm_uid)
              $evm.log(:info, "[Undo backup] remove backup vm #{vm_uid}")
			        connection = $evm.vmdb(:VmOrTemplate).find_by(uid_ems: vm_uid).ext_management_system.connect
              connection.system_service.vms_service.vm_service(vm_uid).remove
            end

            def last_restore
              @last_restore ||= Restore.find_objects(backup_name: @backup.name).max_by(&:created_at)
            end

            def last_backup
              @last_backup ||= last_restore.backup.first
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

Backups::Automate::GenericObject::Methods::Redhat::UndoRestoredVm.new.main
