require 'ovirtsdk4'

def create_template_clone(connection, snapshot, vm_id)
  vm = $evm.vmdb(:Vm).find(vm_id)
  snapshot_name = snapshot.name
  snapshot_name.slice!("clone-")
  vm_name = "cld_cl-" + snapshot_name
  h = {
    :name             => vm_name,
    :cluster          => {
      :name => vm.ems_cluster.name
    },
    :disk_attachments => vm.disks.map do |vm_disk|
      {
        :disk => {
          :id              => vm_disk.filename,
          :storage_domains => [{
            :id => vm.storage.ems_ref.split('/').last
          }]
        }
      }
    end,
    :snapshots        => [{
      :id => snapshot.uid_ems
    }]
  }
  connection.system_service.vms_service.add_from_snapshot(OvirtSDK4::Vm.new(h))
end

def create_template(connection, snapshot, backup)
  vm = $evm.vmdb(:Vm).find(backup.service.first.vms.first.id)
  h = {
    :name => backup.name,
    :vm   => {
      :id               => vm.uid_ems,
      :snapshots        => [{
        :id => snapshot.uid_ems
      }],
      :disk_attachments => vm.disks.map do |vm_disk|
        {
          :disk => {
            :id              => vm_disk.filename,
            :storage_domains => [{
              :id => find_backup_storage
            }]
          }
        }
      end
    }
  }
  connection.system_service.templates_service.add_from_vm_snapshot(OvirtSDK4::Template.new(h))
end

def remove_template(connection, template_uid, backup)
  backup.update!(:status => 'deleting_template')
  connection.system_service.templates_service.template_service(template_uid).remove
end

def create_vm_from_template(connection, restore)
  backup = restore.backup.first
  template = $evm.vmdb(:VmOrTemplate).find(backup.template_id)
  conf = JSON.parse(backup.configuration)
  disks = conf["disks"]
  new_disks = {}
  disks.each do |name, storage|
    new_disks[replace_name_to_filename(name, template)] = storage["storage_type"]
  end
  system_service = connection.system_service
  template_uuid = template.uid_ems
  vms_service = system_service.vms_service
  vms_service.add(
    OvirtSDK4::Vm.new(
      :name             => restore.name.to_s,
      :cluster          => {
        :name => backup.service.first.vms.first.ems_cluster.name.to_s
      },
      :template         => {
        :id => template_uuid
      },
      :disk_attachments => new_disks.map do |name, disk_type|
                             {
                               :disk => {
                                 :id              => name,
                                 :storage_domains => [{
                                   :id => find_storage_for_recovery(disk_type)
                                 }]
                               }
                             }
                           end
    ), :clone => true
  )
end
