module Backups
  module Automate
    module GenericObject
      module Libraries
        module Redhat
          class ClearingAfterBackup
            def initialize(handle = $evm)
              @handle = handle
              @event = @handle.vmdb(:EventStream).find(@handle.root['event_id'])
            end

            def main
              @handle.log(:info, 'Start vm_created method')
              clearing_after_backup
              @handle.log(:info, 'End method')
            end

            private

            def clearing_after_backup
              if /^Creation of Template (bkp_.+) from VM/.match?(@event.message)
                template_uuid = @event.full_data['template']['id']
              end

              template = get_vm_or_template_from_vmdb(template_uuid)
              exit MIQ_OK unless template

              begin
                backup = Backup.find_objects(name: template.name).first
                backup.template = [template]

                backup.update!(status: 'created_template', template_id: template.id)
                backup.update!(status: 'deleting_snapshot')

                @handle.vmdb(:Snapshot).find_by(description: backup.snapshot_uuid).remove

                backup.update!(status: 'deleted_snapshot')
                backup.update!(status: 'ready')
              rescue StandardError
                backup.update!(error: true)
              end
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Libraries::Redhat::ClearingAfterBackup.new.main
