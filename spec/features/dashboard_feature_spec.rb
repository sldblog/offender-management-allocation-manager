require 'rails_helper'

feature 'get dashboard' do
  around do |example|
    travel_to Date.new(2018, 11, 3, 16) do
      example.run
    end
  end

  it 'shows the status page', vcr: { cassette_name: :get_status_feature } do
    signin_user

    visit '/'

    expect(page).to have_css('.dashboard-row', count: 3)
    expect(page).to have_link('Allocated prisoners', href: allocations_path)
    expect(page).to have_link('Awaiting allocation', href: allocations_path(anchor: "awaiting-allocation"))
    expect(page).to have_link('Missing information', href: allocations_path(anchor: "awaiting-tiering"))
  end
end
