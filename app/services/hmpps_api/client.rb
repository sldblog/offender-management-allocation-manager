# frozen_string_literal: true

require 'faraday'
require 'typhoeus/adapters/faraday'

module HmppsApi
  class Client
    APIError = Class.new(StandardError)

    def initialize(root, log404 = true)
      @root = root
      @log404 = log404
      retry_options = {
          # increase the default number of retries from 2 to 5 as 3 doesn't seem to be enough
          max: 5,
          # some useful values as per the Faraday documentation
          # https://lostisland.github.io/faraday/middleware/retry
          # for some reason this middleware doesn't provide sensible defaults
          # but does have some good suggestions in the documentation
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2,
          # we seem to get 502 and 504 statuses from a gateway this side of
          # the Prison API - so retry if we get one of those.
          retry_statuses: [502, 504]
      }
      @connection = Faraday.new do |faraday|
        faraday.request :retry, retry_options

        faraday.options.params_encoder = Faraday::FlatParamsEncoder
        faraday.use Faraday::Response::RaiseError
        faraday.use Faraday::Request::Instrumentation
        faraday.adapter :typhoeus
      end
    end

    # Performs a basic GET request without processing the response. This is mostly
    # used for when we do not want a JSON response from an endpoint.
    def raw_get(route, queryparams: {}, extra_headers: {})
      response = request(
        :get, route, queryparams: queryparams, extra_headers: extra_headers
      )
      response.body
    end

    def get(route, queryparams: {}, extra_headers: {})
      response = request(
        :get, route, queryparams: queryparams, extra_headers: extra_headers
      )

      # Elite2 can return a 204 to mean empty results, and we don't know if
      # it is meant to be a {} or a []. For now, we are going to use nil and
      # let the caller handle it.
      data = if response.status == 204
               nil
             else
               JSON.parse(response.body)
             end

      if block_given?
        yield data, response
      end

      data
    end

    def post(route, body, queryparams: {}, extra_headers: {})
      response = request(
        :post, route, queryparams: queryparams, extra_headers: extra_headers, body: body
      )

      JSON.parse(response.body)
    end

    def put(route, body, queryparams: {}, extra_headers: {})
      response = request(
        :put, route, queryparams: queryparams, extra_headers: extra_headers, body: body
      )

      JSON.parse(response.body)
    end

    def delete(route, queryparams: {}, extra_headers: {})
      request(
        :delete, route, queryparams: queryparams, extra_headers: extra_headers
      )
    end

  private

    def request(method, route, queryparams: {}, extra_headers: {}, body: nil)
      @connection.send(method) do |req|
        req.url(@root + route)
        req.headers['Authorization'] = "Bearer #{token.access_token}"
        req.headers['Content-Type'] = 'application/json' unless body.nil?
        req.headers.merge!(extra_headers)
        req.params.update(queryparams)
        req.body = body.to_json unless body.nil?
      end
    rescue Faraday::ConnectionFailed => e
      AllocationManager::ExceptionHandler.capture_exception(e)
      raise APIError, "Failed to connect to #{@root}"
    rescue Faraday::ResourceNotFound => e
      AllocationManager::ExceptionHandler.capture_exception(e)  if @log404
      raise APIError, "Unexpected status #{e.response[:status]}"
    rescue Faraday::ClientError => e
      AllocationManager::ExceptionHandler.capture_exception(e)
      raise APIError, "Client error: #{e.response[:status]}"
    end

    def token
      HmppsApi::Oauth::TokenService.valid_token
    end
  end
end
