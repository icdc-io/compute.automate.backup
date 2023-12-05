module Backups
  module Automate
    module GenericObject
      module Methods
        module Redhat
          class ResetBackupStatus
            def initialize(handle = $evm)
              @handle = handle
              @service = @handle.root['service']
            end

            def main
              @handle.log(:info, "Start reseting backups in service #{@service.name} (#{@service.id})")
              reset_backup_status
              @handle.log(:info, 'End reseting')
            end

            private

            def reset_backup_status
              created_backups = @service.backups.select { |backup| backup.status.include?('creat') }
              created_backups.each do |backup|
                backup.update(status: 'error', error: true, terminated: true)
              end
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Methods::Redhat::ResetBackupStatus.new.main
