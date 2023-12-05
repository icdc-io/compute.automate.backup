require 'securerandom'

def create_snapshot(vm, new_backup)
  snapshot_uuid = SecureRandom.uuid
  new_backup.update!(status: 'creating_snapshot', snapshot_uuid: snapshot_uuid)
  vm.create_snapshot(snapshot_uuid, snapshot_uuid, false)
rescue StandardError
  new_backup.update!(error: true)
end
