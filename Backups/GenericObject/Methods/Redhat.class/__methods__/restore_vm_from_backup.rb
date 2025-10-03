module Backups
  module Automate
    module GenericObject
      module Methods
        module Redhat
          class RestoreVmFromBackup
            def initialize(handle = $evm)
              @handle = handle
              @backup = @handle.vmdb(:GenericObject).find(@handle.root['backup_id'])
              @backup_service = @backup.service.first
              @backup_vm = @handle.vmdb(:VmOrTemplate).find_by!(name: JSON.parse(@backup.configuration)['vm_name'])
            end

            def main
              exit MIQ_OK if active_backups_count(@backup_service).positive?

              @connection = establish_connection(@backup_vm)

              if @connection.system_service.vms_service.vm_service(@backup_vm.uid_ems).snapshots_service.list.size > 1
                @handle.create_notification(level:   "error",
                                            message: "Cannot restore vm: #{@backup_vm.name}. Please, remove vm's snapshots.")
                @handle.log(:info, "Cannot restore.")
                @handle.log(:info, "Cannot detach Virtual Disk. The disk is already configured in a snapshot. In order to detach it, remove the disk's snapshots.")

                exit MIQ_OK
              end

              @handle.log(:info, "Start restoring #{@backup_vm.name} VM " \
                                 "from backup #{@backup.name} in service #{@backup_service.name}")
              lock_other_service_backups(@backup_service)
              restore_vm_from_backup
              @handle.log(:info, 'End restoring')
            end

            private

            def restore_vm_from_backup
              @backup.update!(status: 'restoring')
              new_restore = create_restore_object

              create_vm_from_template(@connection, new_restore)
            end

            def create_restore_object
              new_restore = Restore.create_object(restore_params)
              new_restore.service = [@backup_service]
              new_restore.backup = [@backup]
              new_restore.add_to_service(@backup_service)
              new_restore.save!
              new_restore
            end

            def restore_params
              {
                name: "rst_#{ENV.fetch('LOCATION_NAME')}_#{@backup_vm.name}",
                status: 'restoring',
                error: false,
                original_vm_uuid: @backup_vm.uid_ems,
                backup_name: @backup.name,
                new_vm_uuid: nil
              }
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Methods::Redhat::RestoreVmFromBackup.new.main
