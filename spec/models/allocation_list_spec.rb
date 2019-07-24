require 'rails_helper'

RSpec.describe AllocationList, type: :model do
  let(:current_allocation) {
    build_stubbed(
      :allocation_version,
      prison: 'LEI'
    )
  }

  let(:middle_allocation1) {
    build_stubbed(
      :allocation_version,
      prison: 'PVI'
    )
  }

  let(:middle_allocation2) {
    build_stubbed(
      :allocation_version,
      prison: 'PVI'
    )
  }

  let(:old_allocation) {
    build_stubbed(
      :allocation_version,
      primary_pom_allocated_at: DateTime.now.utc - 4.days,
      prison: 'LEI',
      event: AllocationVersion::REALLOCATE_PRIMARY_POM,
      event_trigger: AllocationVersion::USER
    )
  }

  it 'can group the allocations correctly', vcr: { cassette_name: :allocation_list_spec } do
    list = described_class.new([current_allocation, middle_allocation1, middle_allocation2, old_allocation])
    expect(list.count).to eq(4)

    results = []

    list.grouped_by_prison do |prison, allocations|
      results << [prison, allocations]
    end

    prison, allocations = results.shift
    expect(prison).to eq('LEI')
    expect(allocations.count).to eq(1)

    prison, allocations = results.shift
    expect(prison).to eq('PVI')
    expect(allocations.count).to eq(2)

    prison, allocations = results.shift
    expect(prison).to eq('LEI')
    expect(allocations.count).to eq(1)
  end
end
