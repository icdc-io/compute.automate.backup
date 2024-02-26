#
# Description: TODO: check Platform -> Service -> Network -> StateMachines -> Methods -> UpdateSecurityGroups
#

require 'coredns'

def clone_security_groups(from_vm, to_vm)
  add_security_groups_info(from_vm)
  update_security_groups(to_vm)
end

def update_security_groups(vm)
  security_groups_info.each do |data|
    ns = vm.ext_management_system.network_manager.openstack_handle.detect_network_service
    nic = vm.nics.first
    next unless nic

    $evm.log(:info, "[ICDC] Process SG for NIC: #{nic.id}")
    new_port = $evm.vmdb(:NetworkPort).find_by(device_id: nic.id)
    next unless new_port

    new_port_id = new_port.ems_ref
    $evm.log(:info, "[ICDC] NIC[#{nic.id}] has port: #{new_port_id}")

    unless new_port_id == data[:old_port_id]
      ns.update_port(new_port_id, { security_groups: data[:port_security_groups] })
    end
  rescue RuntimeError => e
    $evm.log(:error, "[ICDC] Could not set NIC[#{nic.id}]: #{e.message}")
    next # Skip setting group
  end
end

def add_security_groups_info(vm)
  vm.nics.pluck(:uid_ems).each do |nic_id|
    port = $evm.vmdb(:NetworkPort).find_by(device_ref: nic_id)
    port_security_groups = port.security_groups.collect(&:ems_ref)
    next if port_security_groups.empty?

    data = {
      old_port_id: port.ems_ref,
      port_security_groups: port_security_groups
    }

    security_groups_info.push(data)
  end
end

def security_groups_info
  @security_groups_info ||= []
end
