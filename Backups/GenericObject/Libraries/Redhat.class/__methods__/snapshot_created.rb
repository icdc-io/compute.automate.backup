module Backups
  module Automate
    module GenericObject
      module Libraries
        module Redhat
          class SnapshotCreated
            def initialize(handle = $evm)
              @handle = handle
              @event_msg = @handle.vmdb(:EventStream).find(@handle.root['event_id']).message
            end

            def main
              @handle.log(:info, 'Start snapshot created method')
              snapshot_created
              @handle.log(:info, 'End method')
            end

            private

            def snapshot_created
              rematch = @event_msg.match(/^Snapshot '([a-z0-9\-]+)'/)
              exit MIQ_OK unless rematch

              snapshot_uuid = rematch[1]
              backup = Backup.find_objects(snapshot_uuid: snapshot_uuid).first
              exit MIQ_OK unless backup

              begin
                # snapshot = get_snapshot_from_vmdb(snapshot_uuid)

                backup.update!(status: 'created_snapshot') # For future, mb we need also one step in creation backup
                backup.update!(status: 'creating_template')

                vm = @handle.vmdb(:VmOrTemplate).find_by(name: JSON.parse(backup.configuration)['vm_name'])
                connection = establish_connection(vm)
                # ahrechushkin: hot fix just for tests
                # create_template(connection, snapshot, backup)
                s = connection.system_service.vms_service.vm_service(vm.uid_ems).snapshots_service.list.find { |x| x.description == snapshot_uuid }
                backup.update!(snapshot_uuid: s.id)
                snapshot_id = s.id
                create_template_new(connection, snapshot_id, backup)
              rescue StandardError
                backup.update!(error: true)
                exit MIQ_ABORT
              end
            end
          end
        end
      end
    end
  end
end

Backups::Automate::GenericObject::Libraries::Redhat::SnapshotCreated.new.main
