#############################
# ahrechushkin: The main goal of this module is looking for frozen and stucked backup objects.
# When the objects was found we want to go ahead two ways:
# 1. If possible - resume backup process
# 2. Otherwise unlock service, fail backup and optionaly notify operators' about some problems in location
##############################
module Platform
  module Automation
    module System
      module Methods
        class BackupsWatchdog
          def initialize(handle = $evm)
            @handle = handle
            @max_hours = 4
            @start_time = DateTime.now
            @notifications = true
            @broken_backups = []
            @resumed_on_snapshot_phase = []
            @resumed_on_template_phase = []
            @resumed_on_delete_phase = []
          end

          def perform
            @handle.log(:info, "[Backups Watchdog] started at #{@start_time}")
            @handle.log(:info, "Max hours: #{@max_hours} :: Notifications: #{@notifications}")

            @start_time -= (@max_hours + 1).hours
            @end_time = @start_time + 1.hour

            backups = stucked_backups(@start_time, @end_time)

            @handle.log(:info, "[Backups Watchdog] Found #{backups.size} stucked backups " \
                               "from #{@start_time} to #{@end_time}")

            backups.each { |backup| analyze_backup(backup) }

            notify_admins
          end

          private

          def stucked_backups(start_time, end_time)
            backups = @handle.vmdb(:GenericObject).where(
              generic_object_definition_id: Backup.id,
              updated_at: start_time..end_time
            )

            backups.select do |backup|
              next if backup.terminated || backup.error
              next if %w[ready locked restored error].include?(backup.status)

              backup
            end
          end

          def analyze_backup(backup)
            @handle.log(:info, "[Backups Watchdog] Analyze backup #{backup.name} (#{backup.id})")
            case backup.status
            when /creat.*snapshot/
              fix_snapshot_phase(backup)
            when /creat.*template/
              fix_template_phase(backup)
            when /delet.*template/
              fix_delete_phase(backup)
            else
              @broken_backups << backup
            end
          end

          def fix_snapshot_phase(backup)
            snapshot_uuid = backup.snapshot_uuid

            unless snapshot_uuid
              @broken_backups << backup
              return
            end

            snapshot = @handle.vmdb(:Snapshot).find_by(uid_ems: snapshot_uuid)
            template = @handle.vmdb(:VmOrTemplate).find_by(name: backup.name)

            if template.present?
              return fix_template_phase(backup, template)
            elsif snapshot.present?
              recreate_template(backup)
            else
              recreate_snapshot(backup)
            end

            @resumed_on_snapshot_phase << backup
          rescue StandardError => e
            @handle.log(:error, "[Backups Watchdog] can't resume backup " \
                                "#{backup.name} (#{backup.id}) on snapshot phase (#{e.message})")
            @broken_backups << backup
          end

          def fix_template_phase(backup, template = nil)
            template ||= @handle.vmdb(:VmOrTemplate).find_by(name: backup.name)

            if template.present?
              remove_snapshot(backup)
              reset_backup(backup)
            else
              recreate_template(backup)
            end

            @resumed_on_template_phase << backup
          rescue StandardError => e
            @handle.log(:error, "[Backups Watchdog] can't resume backup " \
                                "#{backup.name}(#{backup.id}) on template phase (#{e.message})")
            @broken_backups << backup
          end
          
          def fix_delete_phase(backup, template = nil)
            template ||= @handle.vmdb(:VmOrTemplate).find_by(name: backup.template_uuid) \
                      || @handle.vmdb(:VmOrTemplate).find_by(name: backup.name)
            if template.nil? || template.archived || template.retired
              retire_backup(backup)
            else
              reset_backup(backup)
            end
            @resumed_on_delete_phase << backup
          rescue StandardError => e
            @handle.log(:error, "[Backups Watchdog] can't resume backup " \
                                "#{backup.name}(#{backup.id}) on delete phase (#{e.message})")
            @broken_backups << backup
          end

          def recreate_snapshot(backup)
            vm = $evm.vmdb(:Vm).find_by!(name: JSON.parse(backup.configuration)['vm_name'])
            create_snapshot(vm, backup)
          end

          def recreate_template(backup)
            snapshot = @handle.vmdb(:Snapshot).find_by(uid_ems: backup.snapshot_uuid)
            return recreate_snapshot(backup) unless snapshot

            vm = @handle.vmdb(:Vm).find_by!(name: JSON.parse(backup.configuration)['vm_name'])
            connection = establish_connection(vm)
            create_template(connection, snapshot, backup)
          end

          def remove_snapshot(backup)
            snapshot = @handle.vmdb(:Snapshot).find_by(uid_ems: backup.snapshot_uuid)
            return unless snapshot
            # VMs and snapshots are stored indefinitely
            # so backup can store snapshot_uuid for non-existing VM
            vm = @handle.vmdb(:Vm).find_by(id: snapshot.vm_or_template_id)
            if !vm.present? || vm.archived || vm.retired
              @handle.log(:warn, "[Backups Watchdog] Source VM for snapshot #{snapshot.id} already deleted. Skip removing snapshot")
              return
            end
            # Valid snapshot, remove it
            snapshot.remove
          end

          def reset_backup(backup)
            backup.error = false
            backup.status = 'ready'
            backup.save!
          end
          
          def retire_backup(backup)
            backup.terminated = true
            backup.status = 'deleted'
            backup.save!
          end

          def notify_admins
            return unless @broken_backups.count.positive? ||
                          @resumed_on_template_phase.count.positive? ||
                          @resumed_on_snapshot_phase.count.positive? ||
                          @resumed_on_delete_phase.count.positive?

            @handle.instantiate('/Configuration/Email/Default')

            email_attributes = @handle.object('/Configuration/Email/Default').attributes
            from = email_attributes['from'].to_s
            to = email_attributes['default_recipient'].to_s

            subject = "[Compute] Backups WatchDog report #{DateTime.now.strftime('%FT%H:%M')}"
            email_builder = EmailBuilder.new

            all_broken_backups = {
              'Resumed on snapshot phase' => @resumed_on_snapshot_phase,
              'Resumed on template phase' => @resumed_on_template_phase,
              'Resumed on delete phase' => @resumed_on_delete_phase,
              'Broken' => @broken_backups
            }

            all_backups_size = all_broken_backups.sum { |type, backups| backups.count }
            email_builder.add_message_header(@start_time, @end_time, all_backups_size)

            all_broken_backups.each do |type, backups|
              backups_count = backups.count

              if backups_count.positive?
                email_builder.add_backups_count(type, backups_count)
                email_builder.add_backups_table(backups)
              end
            end

            email_builder.add_help_link
            email_builder.add_signature(email_attributes['signature'])

            @handle.execute('send_email', to, from, subject, email_builder.message_body)
          end
        end

        class EmailBuilder
          attr_reader :message_body

          def initialize(handle = $evm)
            @handle = handle
            @message_body = ''
          end

          def add_message_header(start_time, end_time, backups_count)
            @message_body += "<p>The Backup Watchdog looked for stuck backups created in the time period of " \
                             "#{start_time.strftime('%FT%H:%M')} and #{end_time.strftime('%FT%H:%M')}</p>"
            @message_body += "<p>Found stucked backups: #{backups_count}</p>"
          end

          def add_backups_count(backups_type, backups_size)
            @message_body += "<p><b>#{backups_type} backups - #{backups_size}</b></p>"
          end

          def add_backups_table(backups)
            @message_body += "<table border='1'>"
            @message_body += '<tr><td><b>Backup name</b></td><td><b>Backup ID</b></td></tr>'
            backups.each { |backup| @message_body += "<tr><td>#{backup.name}</td><td>#{backup.id}</td></tr>" }
            @message_body += '</table><br>'
          end

          def add_signature(signature)
            @message_body += signature
          end

          def add_help_link
            help_url = "https://portal.#{ENV.fetch('CPV_DOMAIN')}/services/compute/backups/troubleshoot/backup_problem.html"
            @message_body += "<p>Learn more on <a href='#{help_url}'>How to fix broken backups</a></p>"
          end
        end
      end
    end
  end
end

Platform::Automation::System::Methods::BackupsWatchdog.new.perform
