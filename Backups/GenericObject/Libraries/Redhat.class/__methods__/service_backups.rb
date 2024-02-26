#
# Description: service_backups method that is used for backup
#

def active_backups_count(service)
  backups_in_processing = []

  service.backups.each do |backup|
    next if backup.terminated # skip if backup terminated
    next if backup.status.eql?('ready') || backup.status.eql?('error')

    backups_in_processing.push(backup)
  end

  backups_in_processing.length
end

def lock_other_service_backups(service)
  change_service_backup_statuses(service, 'ready', 'locked')
end

def unlock_other_service_backups(service)
  change_service_backup_statuses(service, 'locked', 'ready')
end

def change_service_backup_statuses(service, backup_status, new_backup_status)
  service.backups.each do |backup|
    next if backup.terminated
    next unless backup.status.eql?(backup_status)

    backup.update!(status: new_backup_status)
  end
end
