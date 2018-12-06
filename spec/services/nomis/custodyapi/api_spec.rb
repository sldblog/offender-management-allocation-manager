require 'rails_helper'

describe Nomis::Custodyapi::Api do
  # Ensure that we have a new instance to prevent other specs interfering
  around do |ex|
    Singleton.__init__(described_class)
    ex.run
    Singleton.__init__(described_class)
  end

  it 'fetches the staff\'s details' do
    allow_any_instance_of(Nomis::Custodyapi::Client).to receive(:get).and_return(
      activenomiscaseload: 'LEI',
    )

    response = described_class.fetch_nomis_staff_details

    expect(response[:activenomiscaseload]).to eq "LEI"
  end
end
