# frozen_string_literal: true

class SummaryService
  PAGE_SIZE = 20 # The number of items to show in the view

  # rubocop:disable Metrics/MethodLength
  def self.summary(summary_type, prison)
    # We expect to be passed summary_type, which is one of :allocated, :unallocated,
    # :pending, or :new_arrivals.  The other types will return totals, and do not contain
    # any data.
    sortable_fields = (summary_type == :allocated ? sort_fields_for_allocated : default_sortable_fields)

    # We want to store the total number of each item so we can show totals for
    # each type of record.
    buckets = { allocated: Bucket.new(sortable_fields),
                unallocated: Bucket.new(sortable_fields),
                pending: Bucket.new(sortable_fields),
                new_arrivals: Bucket.new(sortable_fields)
    }

    offenders = prison.offenders
    active_allocations_hash = AllocationService.active_allocations(offenders.map(&:offender_no), prison.code)

    # We need arrival dates for all offenders and all summary types because it is used to
    # detect new arrivals and so we would not be able to count them without knowing their
    # prison_arrival_date
    add_arrival_dates(offenders) if offenders.any?

    offenders.each do |offender|
      # Having a 'tier' is an alias for having a case information record
      if offender.tier.present?
        # When trying to determine if this offender has a current active allocation, we want to know
        # if it is for this prison.
        if active_allocations_hash.key?(offender.offender_no)
          buckets[:allocated].items << offender
        else
          buckets[:unallocated].items << offender
        end
      elsif new_arrival?(offender)
        buckets[:new_arrivals].items << offender
      else
        buckets[:pending].items << offender
      end
    end

    # For the allocated offenders, we need to provide the allocated POM's
    # name
    buckets[:allocated].items.each do |offender|
      alloc = active_allocations_hash[offender.offender_no]
      offender.allocated_pom_name = restructure_pom_name(alloc.primary_pom_name)
      offender.allocation_date = (alloc.primary_pom_allocated_at || alloc.updated_at)&.to_date
    end

    Summary.new(summary_type, allocated: buckets[:allocated],
                              unallocated: buckets[:unallocated],
                              pending: buckets[:pending],
                              new_arrivals: buckets[:new_arrivals])
  end

# rubocop:enable Metrics/MethodLength

private

  # anyone newly arrived (< 2 days) hasn't been matched via nDelius, so its good to have a separate bucket
  # due to the way nDelius matching works (prisoner arrives on Friday, report run Friday night,
  # NART person picks up report on Monday, sends email to Omic, nDelius process runs Monday night)
  # anyone arriving on Friday won't get picked up for potential allocation via nDelius until
  # Tuesday - so consider them newly arrived even on Monday (when awaiting_allocation_for == 3)
  def self.new_arrival?(offender)
    offender.awaiting_allocation_for < 2 ||
      ((offender.prison_arrival_date.friday? || offender.prison_arrival_date.saturday?) && offender.awaiting_allocation_for < 4)
  end

  def self.sort_fields_for_allocated
    [:last_name, :earliest_release_date, :tier]
  end

  def self.default_sortable_fields
    [:last_name, :earliest_release_date, :awaiting_allocation_for, :tier]
  end

  def self.add_arrival_dates(offenders)
    movements = Nomis::Elite2::MovementApi.admissions_for(offenders.map(&:offender_no))

    offenders.each do |offender|
      arrival = movements.fetch(offender.offender_no, []).reverse.detect { |movement|
        movement.to_agency == offender.prison_id
      }
      offender.prison_arrival_date = [offender.sentence_start_date, arrival&.create_date_time].compact.max
    end
  end

  def self.restructure_pom_name(pom_name)
    name = pom_name.titleize
    return name if name.include? ','

    parts = name.split(' ')
    "#{parts[1]}, #{parts[0]}"
  end
end
