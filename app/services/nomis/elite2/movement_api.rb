# frozen_string_literal: true

module Nomis
  module Elite2
    class MovementApi
      extend Elite2Api

      def self.movements_on_date(date)
        route = '/movements'

        data = e2_client.get(route, queryparams: {
                               movementDate: date.strftime('%F'),
                               fromDateTime: (date - 1.day).strftime('%FT%R')
                             })
        data.map { |movement|
          api_deserialiser.deserialise(Nomis::Movement, movement)
        }
      end

      def self.movements_for(offender_no)
        route = '/movements/offenders'

        data = e2_client.post(route, [offender_no], queryparams: { latestOnly: false, movementTypes: %w[ADM TRN REL] })
        data.sort_by { |k| k['createDateTime'] }.map { |movement|
          api_deserialiser.deserialise(Nomis::Movement, movement)
        }
      end

      def self.admissions_for(offender_nos)
        # admissions need to include transfers from one place to another
        route = '/movements/offenders'

        cache_key = "#{route}_#{Digest::SHA256.hexdigest(offender_nos.to_s)}_ADM_TRN"

        Rails.cache.fetch(cache_key,
                          expires_in: Rails.configuration.cache_expiry) do
          data = e2_client.post(route, offender_nos,
                                queryparams: { latestOnly: false, movementTypes: %w[ADM TRN] }).
            group_by { |x| x['offenderNo'] }.values
          movements = data.map { |d|
            d.sort_by { |k| k['createDateTime'] }.map { |movement|
              api_deserialiser.deserialise(Nomis::Movement, movement)
            }
          }
          # return a hash of offender_no => [Nomis::Movement]
          movements.index_by { |m| m.first.offender_no }
        end
      end

      def self.latest_temp_movement_for(offender_nos)
        route = '/movements/offenders'

        cache_key = "#{route}_#{Digest::SHA256.hexdigest(offender_nos.to_s)}_TAP"

        Rails.cache.fetch(cache_key,
                          expires_in: Rails.configuration.cache_expiry) do
          data = e2_client.post(route, offender_nos,
                                queryparams: { latestOnly: false, movementTypes: %w[TAP] }).
            group_by { |x| x['offenderNo'] }.values
          movements = data.map { |d|
            movement = d.max_by { |k| k['createDateTime'] }
            api_deserialiser.deserialise(Nomis::Movement, movement)
          }
          # only return OUT TAP movements - if the last was an IN, then they haven't moved.
          movements.select { |m| m.direction_code == 'OUT' }.index_by(&:offender_no)
        end
      end
    end
  end
end
