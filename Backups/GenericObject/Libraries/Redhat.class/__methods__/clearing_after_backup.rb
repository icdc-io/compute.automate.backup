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
              return unless /^Creation of Template (bkp_#{ENV.fetch('LOC_NAME')}_.+) from VM/.match?(@event.message)
              
              template_uuid = @event.full_data.dig('template', 'id')
              template_name = @event.full_data.dig('template', 'name')

              begin
                backup = Backup.find_objects(name: template_name).first
                backup.update!(status: 'created_template', template_uuid: template_uuid)
                delete_snapshot(backup)
                backup.update!(status: 'ready')
              rescue StandardError => error
                backup.update!(error: true)
                @handle.log(:error, error.message)
              end
            end
            
            def delete_snapshot(backup)
              backup.update!(status: 'deleting_snapshot')
              vm = @handle.vmdb(:VmOrTemplate).find_by(name: JSON.parse(backup.configuration)['vm_name'])
              connection = establish_connection(vm)
              connection.system_service.vms_service.vm_service(vm.uid_ems).snapshots_service.snapshot_service(backup.snapshot_uuid).remove
              backup.update!(status: 'deleted_snapshot')
            rescue => error
              backup.update!(error: true)
              @handle.log(:error, error.message)
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Libraries::Redhat::ClearingAfterBackup.new.main
