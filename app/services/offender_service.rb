class OffenderService
  def get_offender(offender_no)
    Nomis::Elite2::Api.get_offender(offender_no).tap { |o|
      record = CaseInformation.where(nomis_offender_id: offender_no)

      if !record.empty?
        o.data.tier = record.first.tier
        o.data.case_allocation = record.first.case_allocation
      end

      release = Nomis::Elite2::Api.get_bulk_release_dates([offender_no])
      o.data.release_date = release.data[offender_no]

      o.data.main_offence = Nomis::Elite2::Api.get_offence(o.data.latest_booking_id).data
    }
  end

  # rubocop:disable Metrics/MethodLength
  def get_offenders_for_prison(prison, page_number: 0, page_size: 10)
    offenders = Nomis::Elite2::Api.get_offender_list(
      prison,
      page_number,
      page_size: page_size
    )

    offender_ids = offenders.data.map(&:offender_no)

    tier_map = offender_ids.each_with_object({}) do |id, hash|
      hash[id] = CaseInformation.where(nomis_offender_id: id).first
    end

    release_dates = if offender_ids.count > 0
                      Nomis::Elite2::Api.get_bulk_release_dates(offender_ids)
                    else
                      {}
                    end

    offenders.data = offenders.data.select { |offender|
      record = tier_map[offender.offender_no]
      offender.tier = record.tier if record
      offender.case_allocation = record.case_allocation if record
      offender.release_date = release_dates.data[offender.offender_no]
      offender.release_date.present?
    }
    offenders
  end
  # rubocop:enable Metrics/MethodLength

  def self.get_sentence_details(offender_id_list)
    Nomis::Elite2::Api.get_bulk_sentence_details(offender_id_list).data
  end

  def self.allocations_for_offenders(offender_id_list)
    Allocation.where(
      nomis_offender_id: offender_id_list, active: true
    ).preload(:pom_detail)
  end

  # Takes a list of OffenderShort objects, and returns them with their
  # allocated POM name set in :allocated_pom_name
  def self.set_allocated_pom_name(offenders, caseload)
    pom_names = PrisonOffenderManagerService.get_pom_names(caseload)

    offender_ids = offenders.map(&:offender_no)
    offender_to_staff_hash = allocations_for_offenders(offender_ids).map { |a|
      [a.nomis_offender_id, pom_names[a.pom_detail.nomis_staff_id]]
    }.to_h

    offenders.each do |offender|
      offender.allocated_pom_name = offender_to_staff_hash[offender.offender_no]
    end

    offenders
  end
end
