# frozen_string_literal: true

module HmppsApi
  class CommunityApi
    class KeyDate
      # These are `{typeCode}` values for 'key dates' in the Community API
      HANDOVER_START_DATE = 'POM1'
      RESPONSIBILITY_HANDOVER_DATE = 'POM2'
    end

    def self.client
      host = Rails.configuration.community_api_host
      HmppsApi::Client.new(host + '/secure')
    end

    def self.set_pom(offender_no:, prison:, forename:, surname:)
      safe_offender_no = URI.encode_www_form_component(offender_no)
      route = "/offenders/nomsNumber/#{safe_offender_no}/prisonOffenderManager"

      body = {
        nomsPrisonInstitutionCode: prison,
        officer: {
          forenames: forename,
          surname: surname
        }
      }

      # We don't use a cache here because we're not 'getting' data, but 'pushing' it
      self.client.put(route, body)

      # So long as the API call didn't error, return true
      # The API response body isn't useful to us
      true
    end

    def self.set_handover_dates(offender_no:, handover_start_date:, responsibility_handover_date:)
      safe_offender_no = URI.encode_www_form_component(offender_no)
      base_route = "/offenders/nomsNumber/#{safe_offender_no}/custody/keyDates/"

      # Map dates to the correct `{typeCode}` for the Community API
      dates = {
        KeyDate::HANDOVER_START_DATE => handover_start_date,
        KeyDate::RESPONSIBILITY_HANDOVER_DATE => responsibility_handover_date
      }

      dates.stringify_keys.each do |code, date|
        route = base_route + code

        if date.nil?
          # Delete the date from nDelius
          self.client.delete(route)
        else
          # Create/update the date in nDelius
          body = { date: date.strftime('%F') }
          self.client.put(route, body)
        end
      end

      # So long as the API calls didn't error, return true
      # The API response bodies aren't useful to us
      true
    end
  end
end
