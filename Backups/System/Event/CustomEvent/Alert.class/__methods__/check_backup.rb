def create_backup(vm, backups)
  if backups.length >= vm.tags(:backup_count).first.to_i
    slice_from = vm.tags(:backup_count).first.to_i - 1
    $evm.set_state_var(:templates_to_delete, backups[slice_from..-1])
  end
  $evm.instantiate("/System/Request/CreateBackup")
end

vm = $evm.root['vm']
$evm.log('info', "[DBG] Management event: Backup checker #{vm.name}")
$evm.log('info', "[DBG] vm name #{vm.name}")
service = vm.direct_service
if vm.tags(:backup_period).empty?
  $evm.log('info', "[DBG] don't need backup #{vm.name}")
  exit MIQ_OK
end
backup_period = vm.tags(:backup_period).first
backup_time = vm.tags(:backup_time).first unless vm.tags(:backup_time).empty?
$evm.log('info', "[DBG] backup period #{backup_period}")
# $evm.log('info', "[DBG] backup time #{backup_time}")

keys = service.custom_keys
backups = []

if keys.include? "BACKUP"
  $evm.log('info', "[DBG] backup already in progress #{vm.name}")
  exit MIQ_OK if service.custom_get("Backup") == "Идет восстановление из бэкапа"
end

keys.each do |key|
  backups.push(key) if key.index('BACKUP-')
end
backups = backups.sort.reverse
$evm.log('info', "backups: #{backups}")
case backup_period
when "daily"
  if Time.zone.now.strftime('%H') == backup_time || $evm.get_state_var(:backup) == "Backup в процессе создания"
    create_backup(vm, backups)
  end
when "weekly"
  # $evm.log('info', "[DBG] week days #{Date.today - Date.parse(backups[0].split('-')[-2])}")
  create_backup(vm, backups) if $evm.get_state_var(:backup) == "Backup в процессе создания" || (backups.empty? && Time.zone.now.strftime('%H') == backup_time) || ((Time.zone.today - Date.parse(backups[0].split('-')[-2])).to_i >= 7 && Time.zone.now.strftime('%H') == backup_time)
when "monthly"
  $evm.log('info', "[DBG] month days #{Time.zone.today - Date.parse(backups[0].split('-')[-2])}")
  $evm.log('info', "[DBG] today day #{Time.zone.today.day} and backup day #{Date.parse(backups[0].split('-')[-2]).day}")
  create_backup(vm, backups) if backups.empty? || ((Time.zone.today - Date.parse(backups[0].split('-')[-2]) >= 28).to_i && Time.zone.today.day == Date.parse(backups[0].split('-')[-2]).day) || $evm.get_state_var(:backup) == "Backup в процессе создания"
when "hours_period"
  create_backup(vm, backups) if backups.empty? || (Time.zone.now - Time.zone.parse("#{backups[0].split('-')[-2]}#{backups[0].split('-')[-1]}")).to_i / 60 >= vm.tags(:backup_hours_period).first.to_i * 60 || $evm.get_state_var(:backup) == "Backup в процессе создания"
end
