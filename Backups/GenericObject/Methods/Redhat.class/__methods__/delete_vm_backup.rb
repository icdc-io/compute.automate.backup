module Backups
  module Automate
    module GenericObject
      module Methods
        module Redhat
          class DeleteVmBackup
            def initialize(handle = $evm)
              @handle = handle
              @backup = @handle.vmdb(:GenericObject).find(@handle.root['backup_id'])
            end

            def main
              return if @backup.terminated

              @handle.log(:info, "Start deleting backup #{@backup.name} (#{@backup.id})")
              delete_vm_backup
              @handle.log(:info, 'End deleting backup')
            end

            private

            def delete_vm_backup
              return if backup_template_orphaned_or_archived?
              
              if last_restore && !last_restore.status.in?(['save_restored_vm', 'undo_restored_vm'])
                restore_vms = [last_restore.new_vm_uuid, last_restore.original_vm_uuid] - @backup.service.first.vms.pluck(:uid_ems)
                restore_vms.each do |vm_uuid|
                  @handle.log(:info, "Rmoving vm: \"#{vm_uuid}\"")
                  vm = get_vm_or_template_from_vmdb(vm_uuid)
                  remove_vm(vm)
                end
              end
              
              remove_template_request
            end

            def backup_template_orphaned_or_archived?
              check_archived(backup_template.uid_ems) || check_orphaned(backup_template.uid_ems)
            end

            def backup_template
              @backup_template ||= find_backup_template(@backup.template_id.nil? ? {name: @backup.name} : {id: @backup.template_id})
            end

            def find_backup_template(params = {})
              template = @handle.vmdb(:VmOrTemplate).find_by(params)
              return template if template

              @handle.log(:info, "Template with params [#{params.inspect}] doesn`t exist.")
              @backup.update!(terminated: 'true')
              exit MIQ_OK
            end

            def remove_template_request
              connection = establish_connection(backup_template) # take connection by template
              remove_template(connection, backup_template.uid_ems, @backup)
            rescue StandardError => e
              @handle.log(:error, "Attempt to remove template #{e.message}")
            end
            
            def last_restore
              @last_restore ||= Restore.find_objects(backup_name: @backup.name).max_by(&:created_at)
            end
            
            def remove_vm(vm)
              return unless vm

              connection = establish_connection(vm)
              connection.system_service.vms_service.vm_service(vm.uid_ems).shutdown
              sleep 25

              begin
                remove_dns_records(@backup.service.first, vm)
              	connection.system_service.vms_service.vm_service(vm.uid_ems).remove
              	vm.remove_from_vmdb
              rescue OvirtSDK4::Error
                sleep 15
                @handle.log(:info, "Can't remove original vm. Retrying...")
                retry
              end
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Methods::Redhat::DeleteVmBackup.new.main
