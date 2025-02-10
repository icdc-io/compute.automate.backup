#
# Description: vm networks, dns lib
#

require 'coredns'

def remove_dns_records(service, vm)
  @service = service

  dns_records(vm).each do |dns_record|
    core_dns_domain = dns.domain(dns_record['zone'])
    $evm.log(:info, "Removing Core Dns Record with hostname '#{dns_record['group']}' and ip '#{dns_record['host']}'")
    core_dns_domain.delete({ 'name' => dns_record['name'] })
  rescue StandardError => e
    $evm.log(:warn, "Can't remove DNS record with ip '#{dns_record['host']}' because #{e.message}")
    next
  end
rescue StandardError => e
  $evm.log(:warn, "Can't remove DNS records because #{e.message}")
end

def create_dns_record(ip, account, group, owner)
  core_dns_domain = dns.domain(group)
  $evm.log(:info, "Creating Core Dns Record with hostname '#{group}' and ip '#{ip}'")
  core_dns_domain.add(
    {
      host: ip,
      ttl: 600,
      group: group,
      metadata: {
        account: account,
        owner: owner
      }
    }
  )
end

def dns_records(vm)
  vm_ips = ips(vm)
  raise "Vm ip address can't be blank" if vm_ips.blank?

  dns_records = []

  $evm.log(:info, "Vm IPs: #{vm_ips}")
  account_zones.each do |zone|
    dns.domain(zone).list.each do |record|
      if vm_ips.include?(record['host'])
        $evm.log(:info, "Found [#{record['name']}] from zone: #{zone}")
        dns_records.push(record.merge('zone' => zone))
      end
    end
  rescue StandardError
    nil
  end

  dns_records
end

def dns
  @dns ||= CoreDns::Etcd.new(coredns_address)
end

private

def coredns_address
  @coredns_address ||= ENV.fetch('DNS_SERVER', nil)
  @coredns_address ||= "etcd.dns.#{location_domain}"
end

def location_domain
  @location_domain ||= ENV.fetch('LOCATION_DOMAIN', nil)
  @location_domain ||= "#{location_name}.#{cpv_domain}"
end

def location_name
  @location_name ||= @service.region_description.downcase
end

def cpv_domain
  @cpv_domain ||= ENV.fetch('CPV_DOMAIN', nil)
  @cpv_domain ||= "#{ENV['CPV_NAME'].downcase}.io" # outdated
end

def ips(vm)
  nics = vm&.hardware&.nics || []
  nics.filter_map { |nic| $evm.vmdb(:NetworkPort).find_by(device_id: nic.id)&.ipaddresses}
      .flatten.compact
end

def account_zones
  @account_zones ||= dns.zone('').list_all.select do |zone|
    zone.dig('metadata', 'account') == @service.tenant.name
  end.pluck('name')
end
