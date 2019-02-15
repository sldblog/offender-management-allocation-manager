require "rails_helper"

feature "view POM's caseload" do
  let(:nomis_staff_id) { 485_637 }
  let(:nomis_offender_id) { 'G4273GI' }

  before do
    CaseInformation.create(nomis_offender_id: nomis_offender_id, tier: 'A', case_allocation: 'NPC')
  end

  it 'displays all cases for a specific POM',  vcr: { cassette_name: :show_poms_caseload } do
    signin_user('PK000223')

    visit new_allocates_path(nomis_offender_id, nomis_staff_id)

    click_button 'Complete allocation'

    visit "/poms/485637/my_caseload"

    expect(page).to have_content("My caseload")
    expect(page).to have_content("Abbella, Ozullirn")
  end

  it 'displays all cases that have been allocated to a specific POM in the last week', vcr: { cassette_name: :show_new_allocations } do
    signin_user('PK000223')

    visit new_allocates_path(nomis_offender_id, nomis_staff_id)
    click_button 'Complete allocation'

    visit "/poms/485637/my_caseload"
    click_link('1')

    expect(page).to have_content("New allocations")
    expect(page).to have_content("Abbella, Ozullirn")
  end
end