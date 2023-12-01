#
# Description: storage lib that is used for backups
#

def find_backup_storage
  storage = $evm.vmdb(:Storage)
  backup_disks = storage.find_tagged_with(any: '/backup_disk', ns: '/managed/vm_disk_type')
  storage_domains = storage.find_tagged_with(all: '/provisioning/false', ns: '/managed')

  (backup_disks - storage_domains).last.ems_ref.split('/').last
end

def find_storage_for_recovery(disk_type)
  storage = $evm.vmdb(:Storage)
  disks = storage.find_tagged_with(all: "/storage_type/#{disk_type}", ns: '/managed')
  storage_domains = storage.find_tagged_with(all: '/provisioning/false', ns: '/managed')

  free_disks = (disks - storage_domains).select { |disk| disk.storage_domain_type == 'data' }
  free_disks.max_by(&:free_space).ems_ref.split('/').last
end

def replace_name_to_filename(disk_name, template)
  template.hardware.disks.find { |disk| disk if disk.device_name == disk_name }.filename
end
