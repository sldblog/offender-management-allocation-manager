# frozen_string_literal: true

# This class is inherited by all controllers under the /prisons route
# so that they have @prison and active_prison_id available
class PrisonsApplicationController < ApplicationController
  before_action :authenticate_user, :check_prison_access, :load_staff_member, :service_notifications

protected

  def active_prison_id
    params[:prison_id]
  end

  def ensure_pom
    unless current_user_is_pom?
      redirect_to '/401'
    end
  end

  def current_user_is_pom?
    sso_identity.current_user_is_pom? && pom_at_active_prison?
  end

private

  def check_prison_access
    unless PrisonService.exists?(active_prison_id)
      redirect_to('/401')
      return
    end

    return redirect_to('/401') if caseloads.nil? || !caseloads.include?(active_prison_id)

    @prison = Prison.new(active_prison_id)
    @caseloads = caseloads
  end

  def load_staff_member
    user = HmppsApi::PrisonApi::UserApi.user_details(current_user)
    @staff_member = StaffMember.new(user.staff_id)
    @staff_id = user.staff_id
  end

  def pom_at_active_prison?
    @staff_member.pom_at?(active_prison_id)
  end

  def service_notifications
    roles = [current_user_is_spo? ? 'SPO' : nil, sso_identity.current_user_is_pom? ? 'POM' : nil].compact
    @service_notifications = ServiceNotificationsService.notifications(roles)
  end
end
