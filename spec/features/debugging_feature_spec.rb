require 'rails_helper'

feature 'Provide debugging information for an offender' do
  let(:nomis_offender_id) { "G7806VO" }

  it 'returns information for an unallocated offender', vcr: { cassette_name: :debugging_feature } do
    signin_user
    visit prison_debugging_path('LEI')

    expect(page).to have_text('Debugging')
    fill_in 'offender_no', with: nomis_offender_id
    click_on('search-button')

    expect(page).to have_css('tbody tr', count: 29)
    expect(page).to have_content("Not currently allocated")

    table_row = page.find(:css, 'tr.govuk-table__row#convicted', text: 'Convicted?')

    within table_row do
      expect(page).to have_content('Yes')
    end
  end

  it 'returns information for an allocated offender', vcr: { cassette_name: :debugging_allocated_offender_feature } do
    create(:allocation_version,
           nomis_offender_id: nomis_offender_id,
           primary_pom_name: "Rossana Spinka"
           )
    signin_user
    visit prison_debugging_path('LEI')

    expect(page).to have_text('Debugging')
    fill_in 'offender_no', with: nomis_offender_id
    click_on('search-button')

    expect(page).to have_css('tbody tr', count: 34)

    table_row = page.find(:css, 'tr.govuk-table__row#pom', text: 'POM')

    within table_row do
      expect(page).to have_content('POM Rossana Spinka')
    end
  end

  it 'can handle an incorrect offender number', vcr: { cassette_name: :debugging_incorrect_offender_feature } do
    signin_user
    visit prison_debugging_path('LEI')

    expect(page).to have_text('Debugging')
    fill_in 'offender_no', with: "A1234BC"
    click_on('search-button')

    expect(page).to have_content("No offender was found, please check the offender number and try again")
  end

  it 'can handle no offender number being entered', vcr: { cassette_name: :debugging_no_offender_feature } do
    signin_user
    visit prison_debugging_path('LEI')

    expect(page).to have_text('Debugging')
    fill_in 'offender_no', with: ""
    click_on('search-button')

    expect(page).to have_content("No offender was found, please check the offender number and try again")
  end
end
