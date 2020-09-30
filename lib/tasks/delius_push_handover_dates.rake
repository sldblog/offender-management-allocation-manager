namespace :delius do
  desc 'Push handover dates into nDelius for all offenders across the estate'
  task push_handover_dates: :environment do |_task|
    Rails.logger = Logger.new(STDOUT)

    prisons = PrisonService.prison_codes

    # For each prison...
    prisons.each_with_index do |prison_code, index|
      log_prefix = "[#{index + 1}/#{prisons.count}] [#{prison_code}]"
      Rails.logger.info("#{log_prefix} Getting offenders in prison #{prison_code}")
      offenders = Prison.new(prison_code).offenders

      # For each offender in each prison...
      offenders.each do |offender|
        # Queue a job to push the offender's handover dates
        PushHandoverDatesToDeliusJob.perform_later(offender.offender_no)
      end

      Rails.logger.info("#{log_prefix} Queued jobs for #{offenders.count} offenders")
    end

    Rails.logger.info('Done')
  end
end
