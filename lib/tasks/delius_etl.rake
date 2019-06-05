# frozen_string_literal: true

require 'csv'
require_relative '../../lib/delius/extractor'

namespace :delius_etl do
  desc 'Create CaseInformation records for a specific prison'
  task :onboard, [:prison, :file] => [:environment] do |_task, args|
    if defined?(Rails) && Rails.env.development?
      Rails.logger = Logger.new(STDOUT)
    end

    # Make sure both arguments are specified and bail if not
    Rails.logger.error('No prison specified') if args[:prison].blank?
    Rails.logger.error('No file specified') if args[:file].blank?
    next unless args[:file].present? && args[:prison].present?

    # offenders = fetch_offenders(args[:prison])
    # Rails.logger.info("Found #{offenders.count} for #{args[:prison]}")
    delius_records = load_delius_records(args[:file])
    Rails.logger.info("Found #{delius_records.count} in #{args[:file]}")
    create_case_info(offenders, delius_records)
  end
end

# rubocop:disable Metrics/MethodLength
def fetch_offenders(prison)
  results = []
  number_of_requests = max_requests_count(prison)
  (0..number_of_requests).each do |request_no|
    offenders = OffenderService.get_offenders_for_prison(
      prison,
      page_number: request_no,
      page_size: 200
    )
    break if offenders.blank?

    results << offenders
  end
  results.flatten
end
# rubocop:enable Metrics/MethodLength

def max_requests_count(prison)
  info_request = Nomis::Elite2::OffenderApi.list(prison, 1, page_size: 1)
  (info_request.meta.total_pages / 200) + 1
end

def load_delius_records(file)
  Delius::Extractor.new(file).fetch_records
end

def create_case_info(pffenders, delius_records); end
