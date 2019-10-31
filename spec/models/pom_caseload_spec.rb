require 'rails_helper'

RSpec.describe PomCaseload, type: :model do
  let(:prison) { 'LEI' }
  let(:staff_id) { 123 }
  let(:username) { 'alice' }
  let(:pom) {
    [
      {
        staffId: staff_id,
        username: username,
        position: 'PRO'
      }
    ]
  }

  before do
    stub_poms(prison, pom)

    offenders = [
      { "latestBookingId": 754_207, "offenderNo": "G7514GW", "firstName": "Indeter", "lastName": "Minate-Offender",
        "dateOfBirth": "1990-12-06", "age": 28, "agencyId": prison, "categoryCode": "C", "imprisonmentStatus": "LIFE" },
      { "latestBookingId": 754_206, "offenderNo": "G1234VV", "firstName": "ROSS", "lastName": "JONES",
        "dateOfBirth": "2001-02-02", "age": 18, "agencyId": prison, "categoryCode": "D", "imprisonmentStatus": "SENT03" },
      { "latestBookingId": 754_205, "offenderNo": "G1234AB", "firstName": "ROSS", "lastName": "JONES",
        "dateOfBirth": "2001-02-02", "age": 18, "agencyId": prison, "categoryCode": "D", "imprisonmentStatus": "SENT03" },
      { "latestBookingId": 754_204, "offenderNo": "G1234GG", "firstName": "ROSS", "lastName": "JONES",
        "dateOfBirth": "2001-02-02", "age": 18, "agencyId": prison, "categoryCode": "D", "imprisonmentStatus": "SENT03" }
    ]

    bookings = [
      { "bookingId": 754_207, "offenderNo": "G7514GW", "firstName": "Indeter", "lastName": "Minate-Offender", "agencyLocationId": prison,
        "sentenceDetail": { "sentenceExpiryDate": "2014-02-16", "automaticReleaseDate": "2011-01-28",
                            "licenceExpiryDate": "2014-02-07", "homeDetentionCurfewEligibilityDate": "2011-11-07",
                            "bookingId": 754_207, "sentenceStartDate": "2009-02-08", "automaticReleaseOverrideDate": "2012-03-17",
                            "nonDtoReleaseDate": "2012-03-17", "nonDtoReleaseDateType": "ARD", "confirmedReleaseDate": "2012-03-17",
                            "releaseDate": "2012-03-17" }, "dateOfBirth": "1953-04-15", "agencyLocationDesc": "LEEDS (HMP)",
        "internalLocationDesc": "A-4-013", "facialImageId": 1_399_838 },
      { "bookingId": 754_206, "offenderNo": "G1234VV", "firstName": "ROSS", "lastName": "JONES", "agencyLocationId": prison,
        "sentenceDetail": { "sentenceExpiryDate": "2014-02-16", "automaticReleaseDate": "2011-01-28",
                            "licenceExpiryDate": "2014-02-07", "homeDetentionCurfewEligibilityDate": "2011-11-07",
                            "bookingId": 754_207, "sentenceStartDate": "2009-02-08", "automaticReleaseOverrideDate": "2012-03-17",
                            "nonDtoReleaseDate": "2012-03-17", "nonDtoReleaseDateType": "ARD", "confirmedReleaseDate": "2012-03-17",
                            "releaseDate": "2012-03-17" }, "dateOfBirth": "1953-04-15", "agencyLocationDesc": "LEEDS (HMP)",
        "internalLocationDesc": "A-4-013", "facialImageId": 1_399_838 },
      { "bookingId": 754_205, "offenderNo": "G1234AB", "firstName": "ROSS", "lastName": "JONES", "agencyLocationId": prison,
        "sentenceDetail": { "sentenceExpiryDate": "2014-02-16", "automaticReleaseDate": "2011-01-28",
                            "licenceExpiryDate": "2014-02-07", "homeDetentionCurfewEligibilityDate": "2011-11-07",
                            "bookingId": 754_207, "sentenceStartDate": "2009-02-08", "automaticReleaseOverrideDate": "2012-03-17",
                            "nonDtoReleaseDate": "2012-03-17", "nonDtoReleaseDateType": "ARD", "confirmedReleaseDate": "2012-03-17",
                            "releaseDate": "2012-03-17" }, "dateOfBirth": "1953-04-15", "agencyLocationDesc": "LEEDS (HMP)",
        "internalLocationDesc": "A-4-013", "facialImageId": 1_399_838 },
      { "bookingId": 754_204, "offenderNo": "G1234GG", "firstName": "ROSS", "lastName": "JONES", "agencyLocationId": prison,
        "sentenceDetail": { "sentenceExpiryDate": "2014-02-16", "automaticReleaseDate": "2011-01-28",
                            "licenceExpiryDate": "2014-02-07", "homeDetentionCurfewEligibilityDate": "2011-11-07",
                            "bookingId": 754_207, "sentenceStartDate": "2009-02-08", "automaticReleaseOverrideDate": "2012-03-17",
                            "nonDtoReleaseDate": "2012-03-17", "nonDtoReleaseDateType": "ARD", "confirmedReleaseDate": "2012-03-17",
                            "releaseDate": "2012-03-17" }, "dateOfBirth": "1953-04-15", "agencyLocationDesc": "LEEDS (HMP)",
        "internalLocationDesc": "A-4-013", "facialImageId": 1_399_838 }
    ]

    # Allocate all of the offenders to this POM
    offenders.each do |offender|
      create(:allocation_version, nomis_offender_id: offender[:offenderNo], primary_pom_nomis_id: staff_id)
    end

    stub_multiple_offenders(offenders, bookings)
  end

  it 'can get the allocations for the POM at a specific prison' do
    caseload = described_class.new(staff_id, prison)
    expect(caseload.allocations.count).to eq(4)
  end

  it 'can get tasks within a caseload' do
    caseload = described_class.new(staff_id, prison)
    expect(caseload.tasks_for_offenders.count).to eq(1)
  end

  it 'can get tasks within a caseload for a single offender' do
    offender = OpenStruct.new(offender_no: 'G7514GW', indeterminate_sentence?: true, nps_case?: true)

    caseload = described_class.new(staff_id, prison)
    tasks = caseload.tasks_for_offender(offender)
    expect(tasks.count).to eq(1)
  end

  context 'when a POM has new and old allocations' do
    let(:old) { 8.days.ago }

    let(:old_primary_alloc) {
      Timecop.travel(old) do
        create(
          :allocation_version,
          primary_pom_nomis_id: staff_id,
          nomis_offender_id: 'G7514GW',
          nomis_booking_id: 1_153_753
        )
      end
    }

    let(:old_secondary_alloc) {
      Timecop.travel(old) do
        create(
          :allocation_version,
          primary_pom_nomis_id: other_staff_id,
          nomis_offender_id: 'G1234VV',
          nomis_booking_id: 971_856
        ).tap { |item|
          item.update!(secondary_pom_nomis_id: staff_id)
        }
      end
    }

    let(:primary_alloc) {
      create(
        :allocation_version,
        primary_pom_nomis_id: staff_id,
        nomis_offender_id: 'G1234AB',
        nomis_booking_id: 76_908
      )
    }

    let(:secondary_alloc) {
      create(
        :allocation_version,
        primary_pom_nomis_id: other_staff_id,
        nomis_offender_id: 'G1234GG',
        nomis_booking_id: 31_777
      ).tap { |item|
        item.update!(secondary_pom_nomis_id: staff_id)
      }
    }

    let!(:all_allocations) {
      [old_primary_alloc, old_secondary_alloc, primary_alloc, secondary_alloc]
    }

    let(:other_staff_id) { 485_637 }

    before do
      old_primary_alloc.update!(secondary_pom_nomis_id: other_staff_id)
    end

    it "will get allocations for a POM made within the last 7 days", :versioning, vcr: { cassette_name: :get_new_cases } do
      allocated_offenders = described_class.new(staff_id, prison).allocations.select(&:new_case?)
      expect(allocated_offenders.count).to eq 2
      expect(allocated_offenders.map(&:responsibility)).to match_array %w[Supporting Co-Working]
    end
  end
end
