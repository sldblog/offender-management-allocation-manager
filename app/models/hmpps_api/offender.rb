# frozen_string_literal: true

module HmppsApi
  class Offender < OffenderBase
    include Deserialisable

    attr_accessor :main_offence

    attr_reader :reception_date, :prison_id

    def initialize(fields = {})
      super fields
      # Allow this object to be reconstituted from a hash, we can't use
      # from_json as the one passed in will already be using the snake case
      # names whereas from_json is expecting the elite2 camelcase names.
      @gender = fields[:gender]
      @booking_id = fields[:booking_id]
      @prison_id = fields[:prison_id]
      @reception_date = fields[:reception_date]
    end

    def self.from_json(payload)
      Offender.new.tap { |obj|
        obj.load_from_json(payload)
      }
    end

    # This must only reference fields that are present in
    # https://gateway.t3.nomis-api.hmpps.dsd.io/elite2api/swagger-ui.html#//prisoners/getPrisonersOffenderNo
    def load_from_json(payload)
      @booking_id = payload['latestBookingId']&.to_i
      @prison_id = payload['latestLocationId']
      @reception_date = deserialise_date(payload, 'receptionDate')

      super(payload)
    end
  end
end
