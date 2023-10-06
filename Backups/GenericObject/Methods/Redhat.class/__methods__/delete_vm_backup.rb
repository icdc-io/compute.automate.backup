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
              @handle.log('info', 'End deleting backup')
            end

            private

            def delete_vm_backup
              if @backup.template_id.nil?
                # TODO: if there is no VM in service may be need to take default ext_management_system
                #       or take service template which used to deploy this service
                return @backup.destroy! if backup_vm.nil?

                backup_name = @backup.name
                template = connection.system_service.templates_service.list.find do |template_service|
                  template_service.name == backup_name
                end
                return @backup.destroy! if template.nil?

                remove_template_request(template.id)
              else
                return if backup_template_orphaned_or_archived?

                remove_template_request(backup_template.uid_ems)
              end
            end

            def connection
              @connection ||= establish_connection(backup_vm_or_template) # take connection by vm or template
            end

            def backup_vm_or_template
              @backup_vm_or_template ||= @backup.template_id.nil? ? backup_vm : backup_template
            end

            def backup_vm
              @backup_vm ||= @backup.service.first.vms.first
            end

            def backup_template
              @backup_template ||= @handle.vmdb(:VmOrTemplate).find(@backup.template_id)
            rescue StandardError
              @handle.log(:info, "Template with id [#{@backup.template_id}] doesn`t exist.")
              @backup.update!(terminated: 'true')
              exit MIQ_OK
            end

            def backup_template_orphaned_or_archived?
              is_archived = check_archived(backup_template.uid_ems)
              is_orphaned = check_orphaned(backup_template.uid_ems)
              is_archived || is_orphaned
            end

            def remove_template_request(template_id)
              remove_template(connection, template_id, @backup)
            rescue StandardError => e
              @handle.log(:error, "Attempt to remove template #{e.message}")
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Methods::Redhat::DeleteVmBackup.new.main
