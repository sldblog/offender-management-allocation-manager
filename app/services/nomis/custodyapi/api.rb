module Nomis
  module Custodyapi
    class Api
      include Singleton

      class << self
        delegate :fetch_nomis_staff_details, to: :instance
      end

      def initialize
        host = Rails.configuration.nomis_oauth_host
        @custodyapi_client = Nomis::Custodyapi::Client.new(host)
      end

      def fetch_nomis_staff_details
        route = '/custodyapi/api/nomis-staff-users/PK000223'
        @custodyapi_client.get(route)
      end
    end
  end
end
