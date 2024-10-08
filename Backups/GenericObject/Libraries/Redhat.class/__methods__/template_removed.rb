module Backups
  module Automate
    module GenericObject
      module Libraries
        module Redhat
          class TemplateRemoved
            def initialize(handle = $evm)
              @handle = handle
              @event_msg = @handle.vmdb(:EventStream).find(@handle.root['event_id']).message
            end

            def main
              @handle.log(:info, 'Start template removed method')
              template_removed
              @handle.log(:info, 'End method')
            end

            private

            def template_removed
              rematch = @event_msg.match(/^Removal of Template (bkp_#{ENV.fetch('LOCATION_NAME')}_.+) has been completed./)
              template_name = rematch[1] if rematch
              return unless template_name

              backup = Backup.find_objects(name: template_name, status: 'deleting_template').max_by(&:created_at)
              backup.update!(status: 'deleted', terminated: true)
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Libraries::Redhat::TemplateRemoved.new.main
