require 'rails_helper'

RSpec.feature "ChangeParoleReviewDates", :versioning, type: :feature do
  # This ID has an indeterminate sentence
  let(:nomis_offender_id) { 'G0549UO' }
  let!(:case_info) { create(:case_information, nomis_offender_id: nomis_offender_id) }
  let!(:alloc) { create(:allocation, nomis_offender_id: nomis_offender_id, primary_pom_nomis_id: 485_926) }
  let(:year) { Time.zone.today.year + 1 }
  let(:yesterday) { Time.zone.yesterday }

  before do
    signin_user
  end

  it 'updates the date',  vcr: { cassette_name: :change_parole_date } do
    visit prison_allocation_path('LEI', nomis_offender_id)

    click_link 'Update'

    fill_in 'parole_review_date_form_parole_review_date_dd', with: 13
    fill_in 'parole_review_date_form_parole_review_date_mm', with: 5
    fill_in 'parole_review_date_form_parole_review_date_yyyy', with: year

    click_button 'Update'

    expect(case_info.reload.parole_review_date).to eq(Date.new(year, 5, 13))
  end

  it 'bounces properly', vcr: { cassette_name: :change_parole_date_bounce } do
    visit prison_allocation_path('LEI', nomis_offender_id)

    click_link 'Update'

    fill_in 'parole_review_date_form_parole_review_date_dd', with: 13
    fill_in 'parole_review_date_form_parole_review_date_mm', with: 5

    click_button 'Update'

    expect(page).to have_content("Parole review date must be after #{yesterday}")
    expect(case_info.reload.parole_review_date).to be_nil
  end
end
