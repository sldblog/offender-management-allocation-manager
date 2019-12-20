# frozen_string_literal: true

class CaseInformationController < PrisonsApplicationController
  before_action :set_case_info, only: [:edit, :edit_prd, :show]
  before_action :set_prisoner_from_url, only: [:new, :edit, :edit_prd, :show]

  def new
    @case_info = CaseInformation.new(
      nomis_offender_id: nomis_offender_id_from_url
    )
  end

  def edit
    if @case_info.probation_service == 'England'
      @case_info.last_known_address = 'No'
    else
      @case_info.last_known_address = 'Yes'
    end
  end

  # Just edit the parole_review_date field
  def edit_prd
    # blank out old value as it's not relevant
    @case_info.parole_review_date = nil
  end

  def show
    @delius_data = DeliusData.where(noms_no: nomis_offender_id_from_url)

    if @delius_data.empty?
      @delius_errors = [DeliusImportError.new(
        nomis_offender_id: nomis_offender_id_from_url,
        error_type: DeliusImportError::MISSING_DELIUS_RECORD
      )]
    else
      @delius_errors = DeliusImportError.where(
        nomis_offender_id: nomis_offender_id_from_url
      )
    end
    last_delius = DeliusData.order(:updated_at).last
    if last_delius.present?
      @next_update_date = last_delius.updated_at + 1.day
    else
      @next_update_date = Date.tomorrow
    end
  end

  def create
    @case_info = CaseInformation.create(
      nomis_offender_id: case_information_params[:nomis_offender_id],
      tier: case_information_params[:tier],
      welsh_offender: case_information_params[:welsh_offender],
      case_allocation: case_information_params[:case_allocation],
      probation_service: case_information_params[:probation_service],
      last_known_address: case_information_params[:last_known_address],
      local_divisional_unit_id: case_information_params[:local_divisional_unit_id],
      manual_entry: true
    )

    scotland_or_ni_address
    other_address

    if @case_info.valid?
      @case_info.save
      redirect_to prison_summary_pending_path(active_prison_id, sort: params[:sort], page: params[:page])
    else
      case_info_errors
    end
  end

  def update
    @case_info = CaseInformation.find_by(
      nomis_offender_id: case_information_params[:nomis_offender_id]
    )
    @prisoner = prisoner(case_information_params[:nomis_offender_id])

    update_scotland_or_ni
    update_england
    update_wales

    # The only item that can be badly entered is parole_review_date
    if parole_update?
      address = @case_info.probation_service == 'England' ? 'No' : 'Yes'
      if @case_info.update(case_information_params.merge(manual_entry: true, last_known_address: address))
        redirect_to new_prison_allocation_path(active_prison_id, @case_info.nomis_offender_id)
      else
        render 'edit_prd'
      end
    end
  end

private

  def set_prisoner_from_url
    @prisoner = prisoner(nomis_offender_id_from_url)
  end

  def set_case_info
    @case_info = CaseInformation.find_by(
      nomis_offender_id: nomis_offender_id_from_url
    )
  end

  def prisoner(nomis_id)
    @prisoner ||= OffenderService.get_offender(nomis_id)
  end

  def nomis_offender_id_from_url
    params.require(:nomis_offender_id)
  end

  def case_information_params
    params.require(:case_information).
      permit(:nomis_offender_id, :tier, :case_allocation, :welsh_offender,
             :last_known_address, :probation_service, :parole_review_date_dd,
             :parole_review_date_mm, :parole_review_date_yyyy, :local_divisional_unit_id)
  end

  def scotland_or_ni_address
    return unless ['Scotland', 'Northern Ireland'].include?(case_information_params[:probation_service])

    @case_info.probation_service = case_information_params[:probation_service]
    @case_info.tier = 'N/A'
    @case_info.welsh_offender = 'No'
    @case_info.case_allocation = 'N/A'
    @case_info.local_divisional_unit = nil
  end

  def other_address
    # setting the welsh_offender will not be needed if we
    # do a data migration to change all welsh offenders to probation service = Wales

    return if case_information_params[:probation_service] == 'Scotland' ||
      case_information_params[:probation_service] == 'Northern Ireland'

    if case_information_params[:last_known_address] == 'No'
      @case_info.probation_service = 'England'
      @case_info.welsh_offender = 'No'
    elsif case_information_params[:probation_service] == 'Wales'
      @case_info.welsh_offender = 'Yes'
    end

    unless @case_info.local_divisional_unit_id.nil?
      @case_info.local_divisional_unit_id = case_information_params[:local_divisional_unit_id]
    end
  end

  def case_info_errors
    if case_information_params[:last_known_address].nil?
      @case_info.errors.messages.reject! do |f, _m|
        f != :probation_service && f != :last_known_address
      end
      display_address_page
    elsif case_information_params[:last_known_address] == 'Yes' && case_information_params[:probation_service].nil?
      @case_info.errors.messages.select! do |f, _m|
        f == :probation_service
      end
      display_address_page
    else
      clear_errors
      display_missing_info_page
    end
  end

  def display_address_page
    @prisoner = prisoner(case_information_params[:nomis_offender_id])
    render :new
  end

  def display_missing_info_page
    @prisoner = prisoner(case_information_params[:nomis_offender_id])
    @case_info.probation_service = 'England' if @case_info.last_known_address == 'No'
    render :missing_info
  end

  def clear_errors
    return unless params[:form_page] == 'address'

    @case_info.errors.clear
  end

  def parole_update?
    case_information_params.key?(:parole_review_date_dd)
  end

  def update_scotland_or_ni
    return unless case_information_params[:last_known_address] == 'Yes' &&
    (case_information_params[:probation_service] == 'Scotland' ||
    case_information_params[:probation_service] == 'Northern Ireland')

    @case_info.update(probation_service: case_information_params[:probation_service],
                      tier: 'N/A',
                      welsh_offender: 'No',
                      case_allocation: 'N/A',
                      local_divisional_unit_id: nil,
                      last_known_address: 'Yes',
                      manual_entry: true)

    redirect_to new_prison_allocation_path(active_prison_id, @case_info.nomis_offender_id)
  end

  def update_england
    return unless case_information_params[:last_known_address] == 'No'

    @case_info.update(last_known_address: case_information_params[:last_known_address],
                      probation_service: 'England',
                      tier: case_information_params[:tier],
                      welsh_offender: 'No',
                      case_allocation: case_information_params[:case_allocation],
                      local_divisional_unit_id: case_information_params[:local_divisional_unit_id],
                      manual_entry: true)

    redirect_to new_prison_allocation_path(active_prison_id, @case_info.nomis_offender_id)
  end

  def update_wales
    return unless case_information_params[:last_known_address] == 'Yes' &&
      case_information_params[:probation_service] == 'Wales'

    @case_info.update(probation_service: 'Wales',
                      last_known_address: 'Yes',
                      welsh_offender: 'Yes',
                      tier: case_information_params[:tier],
                      case_allocation: case_information_params[:case_allocation],
                      local_divisional_unit_id: case_information_params[:local_divisional_unit_id],
                      manual_entry: true)

    redirect_to new_prison_allocation_path(active_prison_id, @case_info.nomis_offender_id)
  end
end
