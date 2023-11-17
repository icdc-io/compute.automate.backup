module Backups
  module Automate
    module GenericObject
      module Methods
        module Redhat
          class CreateVmBackup
            def initialize(handle = $evm)
              @handle = handle
              @service = @handle.root['service'] || @handle.vmdb(:Service).find(@handle.root['service_id'])
              @vm = @handle.vmdb(:VmOrTemplate).find_by(id: @handle.root['vm_id']) # vm_id can be 'all' or id of vm or nil
            end

            def main
              exit MIQ_OK if active_backups_count(@service).positive?

              @handle.log(:info, "Start creating backup for VM #{@vm&.name} in service #{@service.name}")
              create_vm_backup
              @handle.log(:info, 'End creating backup')
            end

            private

            def create_vm_backup
              vms = backup_for_all_vms? ? @service.vms : [@vm]
              vms.compact.each do |vm|
                new_backup = Backup.create_object(backup_params_for_vm(vm))
                new_backup.service = [vm.direct_service]
                new_backup.add_to_service(vm.direct_service)
                new_backup.save!
                create_snapshot(vm, new_backup)
              end
            end

            def backup_for_all_vms?
              @handle.root['vm_id'] == 'all'
            end

            def backup_params_for_vm(vm)
              {
                name: "bkp_#{vm.id}_#{Time.now.strftime('%Y%m%d-%H%M')}", # rubocop:disable Rails/TimeZone
                status: 'not_started',
                error: false,
                snapshot_uuid: nil,
                template_id: nil,
                terminated: false,
                configuration: save_vm_configuration(vm).to_json,
                description: backup_description
              }
            end

            def backup_description
              @handle.root['backup_name'].blank? ? 'Manual backup' : @handle.root['backup_name']
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Methods::Redhat::CreateVmBackup.new.main
