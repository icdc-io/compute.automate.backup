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

              remove_template_request
            end

            def backup_template_orphaned_or_archived?
              is_archived = check_archived(backup_template.uid_ems)
              is_orphaned = check_orphaned(backup_template.uid_ems)
              is_archived || is_orphaned
            end

            def backup_template
              @backup_template ||= if @backup.template_id.nil?
                                     find_backup_template(name: @backup.name)
                                   else
                                     find_backup_template(id: @backup.template_id)
                                   end
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
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Methods::Redhat::DeleteVmBackup.new.main
