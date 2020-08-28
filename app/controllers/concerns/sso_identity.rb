class SsoIdentity
  def initialize(session)
    @sso_identity = session[:sso_data]
  end

  def absent?
    @sso_identity.nil?
  end

  def to_s
    current_user
  end

  def current_user
    @sso_identity['username'] if @sso_identity.present?
  end

  def current_user_is_spo?
    roles.include?('ROLE_ALLOC_MGR')
  end

  def is_global_admin?
    # TODO - change this to roles.include?('ROLE_MOIC_ADMIN') (or whatever name is chosen)
    # once the name has been agreed and the role has been set up in T3/preprod/production
    current_user_is_spo? && caseloads.size == PrisonService.prison_codes.size
  end

  def current_user_is_pom?
    roles.include?('ROLE_ALLOC_CASE_MGR')
  end

  def default_prison_code
    @sso_identity['active_caseload'] if @sso_identity.present?
  end

  def caseloads
    if @sso_identity.blank?
      []
    else
      @sso_identity.fetch('caseloads').reject { |c| c.casecmp('NWEB') == 0 }
    end
  end

  def allowed?
    roles.include?('ROLE_ALLOC_MGR') || roles.include?('ROLE_ALLOC_CASE_MGR')
  end

  def session_expired?
    Time.current > Time.zone.at(@sso_identity['expiry'])
  end

private

  def roles
    @roles ||= if @sso_identity.present?
                 @sso_identity['roles']
               else
                 #:nocov:
                 []
                 #:nocov:
               end
  end
end
