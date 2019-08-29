require 'rails_helper'
require_relative '../../app/services/nomis/models/movement'

describe MovementService do
  let!(:new_offender_court) { create(:movement, offender_no: 'G4273GI', from_agency: 'COURT')   }
  let!(:new_offender_nil) { create(:movement, offender_no: 'G4273GI', from_agency: nil)   }
  let!(:transfer_out) { create(:movement, offender_no: 'G4273GI', direction_code: 'OUT', movement_type: 'TRN')   }

  it "can get recent movements",
     vcr: { cassette_name: :movement_service_recent_spec }  do
    movements = described_class.movements_on(Date.iso8601('2019-02-20'))
    expect(movements).to be_kind_of(Array)
    expect(movements.length).to eq(2)
    expect(movements.first).to be_kind_of(Nomis::Models::Movement)
  end

  it "can filter transfer type results",
     vcr: { cassette_name: :movement_service_filter_type_spec }  do
    movements = described_class.movements_on(
      Date.iso8601('2019-02-20'),
      type_filters: [Nomis::Models::MovementType::TRANSFER]
    )
    expect(movements).to be_kind_of(Array)
    expect(movements.length).to eq(0)
  end

  it "can filter admissions",
     vcr: { cassette_name: :movement_service_filter_adm_spec }  do
    movements = described_class.movements_on(
      Date.iso8601('2019-03-12'),
      type_filters: [Nomis::Models::MovementType::ADMISSION]
    )
    expect(movements).to be_kind_of(Array)
    expect(movements.length).to eq(1)
    expect(movements.first).to be_kind_of(Nomis::Models::Movement)
    expect(movements.first.movement_type).to eq(Nomis::Models::MovementType::ADMISSION)
  end

  it "can filter release type results",
     vcr: { cassette_name: :movement_service_filter_release_spec }  do
    movements = described_class.movements_on(
      Date.iso8601('2019-02-20'),
      type_filters: [Nomis::Models::MovementType::RELEASE]
    )
    expect(movements).to be_kind_of(Array)
    expect(movements.length).to eq(2)
    expect(movements.first).to be_kind_of(Nomis::Models::Movement)
    expect(movements.first.movement_type).to eq(Nomis::Models::MovementType::RELEASE)
  end

  it "can filter results by direction IN",
     vcr: { cassette_name: :movement_service_filter_direction_in_spec }  do
    movements = described_class.movements_on(
      Date.iso8601('2019-03-12'),
      direction_filters: [Nomis::Models::MovementDirection::IN]
    )
    expect(movements).to be_kind_of(Array)
    expect(movements.length).to eq(1)
    expect(movements.first).to be_kind_of(Nomis::Models::Movement)
    expect(movements.first.direction_code).to eq(Nomis::Models::MovementDirection::IN)
  end

  it "can filter results by direction OUT",
     vcr: { cassette_name: :movement_service_filter_direction_out_spec }  do
    movements = described_class.movements_on(
      Date.iso8601('2019-02-20'),
      direction_filters: [Nomis::Models::MovementDirection::OUT]
    )
    expect(movements).to be_kind_of(Array)
    expect(movements.length).to eq(2)
    expect(movements.first).to be_kind_of(Nomis::Models::Movement)
    expect(movements.first.direction_code).to eq(Nomis::Models::MovementDirection::OUT)
  end

  it "can ignore movements OUT",
     vcr: { cassette_name: :movement_service_ignore_out_spec }  do
    processed = described_class.process_movement(transfer_out)
    expect(processed).to be false
  end

  it "can ignore new offenders arriving at prison when from_agency is outside the prison estate",
     vcr: { cassette_name: :movement_service_ignore_new__from_court_spec }  do
    processed = described_class.process_movement(new_offender_court)
    expect(processed).to be false
  end

  it "can ignore new offenders arriving at prison when from_agency is nil",
     vcr: { cassette_name: :movement_service_ignore_new_from_nil_spec }  do
    processed = described_class.process_movement(new_offender_nil)
    expect(processed).to be false
  end

  describe "processing an offender transfer" do
    let!(:allocation) { create(:allocation_version, nomis_offender_id: 'G4273GI')   }
    let!(:transfer_adm) { create(:movement, offender_no: 'G4273GI', from_agency: 'PRI', to_agency: 'PVI')   }
    let!(:transfer_adm_no_to_agency) { create(:movement, offender_no: 'G4273GI', to_agency: 'COURT')   }
    let!(:transfer_in) { create(:movement, offender_no: 'G4273GI', direction_code: 'IN', movement_type: 'ADM', from_agency: 'VEI', to_agency: 'CFI')   }
    let!(:admission) { create(:movement, offender_no: 'G4273GI', to_agency: 'LEI', from_agency: 'COURT')   }

    let!(:existing_allocation) { create(:allocation_version, nomis_offender_id: 'G4273GI', prison: 'LEI')   }
    let!(:existing_alloc_transfer) { create(:movement, offender_no: 'G4273GI', from_agency: 'PRI', to_agency: 'LEI')   }

    it "can process transfers were offender already allocated at new prison",
       vcr: { cassette_name: :movement_service_transfer_in_existing_spec }  do
      expect(existing_allocation.prison).to eq('LEI')
      processed = described_class.process_movement(existing_alloc_transfer)
      expect(processed).to be false
    end

    it "can process transfer movements IN",
       vcr: { cassette_name: :movement_service_transfer_in_spec }  do
      processed = described_class.process_movement(transfer_adm)
      updated_allocation = AllocationVersion.find_by(nomis_offender_id: transfer_adm.offender_no)

      expect(updated_allocation.primary_pom_name).to be_nil
      expect(updated_allocation.event).to eq 'deallocate_primary_pom'
      expect(updated_allocation.event_trigger).to eq 'offender_transferred'
      expect(processed).to be true
    end

    it "can process a movement with invalid 'to' agency",
       vcr: { cassette_name: :movement_service_transfer_in_spec }  do
      processed = described_class.process_movement(transfer_adm_no_to_agency)
      expect(processed).to be false
    end

    it "can process a movement with no 'to' agency",
       vcr: { cassette_name: :movement_service_admission_in_spec }  do
      processed = described_class.process_movement(admission)
      expect(processed).to be false
    end

    it "will not process offenders on remand",
       vcr: { cassette_name: :movement_service_transfer_in__not_convicted_spec }  do
      allow(OffenderService).to receive(:get_offender).and_return(Nomis::Models::Offender.new.tap{ |o|
        o.convicted_status = "Remand"
      })
      processed = described_class.process_movement(transfer_in)
      expect(processed).to be false
    end
  end

  describe "processing an offender release" do
    let!(:valid_release) { create(:movement, offender_no: 'G4273GI', direction_code: 'OUT', movement_type: 'REL', to_agency: 'OUT', from_agency: 'BAI')   }
    let!(:invalid_release1) { create(:movement, offender_no: 'G4273GI', direction_code: 'OUT', movement_type: 'REL', to_agency: 'LEI')   }
    let!(:invalid_release2) { create(:movement, offender_no: 'G4273GI', direction_code: 'OUT', movement_type: 'REL', from_agency: 'COURT')   }

    let!(:case_info) { create(:case_information, nomis_offender_id: 'G4273GI') }
    let!(:allocation) { create(:allocation_version, nomis_offender_id: 'G4273GI') }

    it "can process release movements", vcr: { cassette_name: :movement_service_process_release_spec }  do
      processed = described_class.process_movement(valid_release)
      updated_allocation = AllocationVersion.find_by(nomis_offender_id: valid_release.offender_no)

      expect(CaseInformationService.get_case_information([valid_release.offender_no])).to be_empty
      expect(updated_allocation.event_trigger).to eq 'offender_released'
      expect(updated_allocation.prison).to eq 'LEI'
      expect(processed).to be true
    end

    it "can ignore invalid release movements", vcr: { cassette_name: :movement_service_process_release_invalid_spec }  do
      processed = described_class.process_movement(invalid_release1)
      expect(processed).to be false

      processed = described_class.process_movement(invalid_release2)
      expect(processed).to be false
    end
  end
end
