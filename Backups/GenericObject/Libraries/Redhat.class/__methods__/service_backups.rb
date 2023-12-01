#
# Description: service_backups method that is used for backup
#

def active_backups_count(service) # TODO: make for one vm
  backups_in_processing = []

  service.generic_objects.each do |generic_object|
    next if not_terminated_backup?(generic_object) ||
            (generic_object.status.eql?('ready') || generic_object.status.eql?('error'))

    backups_in_processing.push(generic_object)
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
  service.generic_objects.each do |generic_object|
    next if not_terminated_backup?(generic_object) || !generic_object.status.eql?(backup_status)

    generic_object.update!(status: new_backup_status)
  end
end

def not_terminated_backup?(generic_object)
  !generic_object.name.start_with?('bkp_') || generic_object.terminated
end
