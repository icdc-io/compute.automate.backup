require 'ovirtsdk4'

def create_template(connection, snapshot, backup)
  vm = $evm.vmdb(:Vm).find_by!(name: JSON.parse(backup.configuration)['vm_name'])

  h = {
    name: backup.name,
    vm: {
      id: vm.uid_ems,
      snapshots: [{
        id: snapshot.uid_ems
      }],
      disk_attachments: vm.disks.map do |vm_disk|
        {
          disk: {
            id: vm_disk.filename,
            storage_domains: [{
              id: find_backup_storage
            }]
          }
        }
      end
    }
  }

  connection.system_service.templates_service.add_from_vm_snapshot(OvirtSDK4::Template.new(h))
end

def create_template_new(connection, snapshot_id, backup)
  vm = $evm.vmdb(:Vm).find_by!(name: JSON.parse(backup.configuration)['vm_name'])

  h = {
    name: backup.name,
    vm: {
      id: vm.uid_ems,
      snapshots: [{
        id: snapshot_id
      }],
      disk_attachments: vm.disks.map do |vm_disk|
        {
          disk: {
            id: vm_disk.filename,
            storage_domains: [{
              id: find_backup_storage
            }]
          }
        }
      end
    }
  }

  connection.system_service.templates_service.add_from_vm_snapshot(OvirtSDK4::Template.new(h))
end

def remove_template(connection, template_uid, backup)
  backup.update!(status: 'deleting_template')
  connection.system_service.templates_service.template_service(template_uid).remove
end

def create_vm_from_template(connection, restore)
  backup = restore.backup.first
  conf = JSON.parse(backup.configuration)
  vm = $evm.vmdb(:Vm).find_by!(name: conf['vm_name'])
  
  disks = conf['disks']
  template_disks = get_template_disks(connection, backup.template_uuid)
  disk_attachments = disks.map do |name, storage|
    {
      disk: {
        id: template_disks[name],
        storage_domains: [{id: find_storage_for_recovery(storage['storage_type'])}]
      }
    }
  end

  vms_service = connection.system_service.vms_service

  vms_service.add(
    OvirtSDK4::Vm.new(
      name: restore.name.to_s,
      cluster: {
        name: vm.ems_cluster.name.to_s
      },
      template: {
        id: backup.template_uuid
      },
      disk_attachments: disk_attachments
    ), clone: true
  )
end

def get_template_disks(connection, template_uuid)
  disks = connection.system_service.templates_service.template_service(template_uuid).disk_attachments_service.list.to_h do |disk|
    [connection.system_service.disks_service.disk_service(disk.id).get.name, disk.id]
  end
end
