class CaseInformationController < ApplicationController
  before_action :authenticate_user

  def new
    @case_info = CaseInformation.new(
      nomis_offender_id: nomis_offender_id_from_url
    )

    @prisoner = prisoner(nomis_offender_id_from_url)
  end

  def create
    @case_info = CaseInformation.create(
      nomis_offender_id: case_information_params[:nomis_offender_id],
      tier: case_information_params[:tier],
      case_allocation: case_information_params[:case_allocation]
    )

    return redirect_to summary_path(anchor: 'awaiting-information') if @case_info.valid?

    @prisoner = prisoner(case_information_params[:nomis_offender_id])
    render :new
  end

private

  def prisoner(nomis_id)
    @prisoner ||= OffenderService.new.get_offender(nomis_id)
  end

  def nomis_offender_id_from_url
    params.require(:nomis_offender_id)
  end

  def case_information_params
    params.require(:case_information).
      permit(:nomis_offender_id, :tier, :case_allocation)
  end
end
