require 'rails_helper'

describe HmppsApi::Client do
  let(:api_host) { Rails.configuration.prison_api_host }
  let(:client) { described_class.new(api_host) }
  let(:token_service) { HmppsApi::Oauth::TokenService }
  let(:access_token) { "access_token" }
  let(:valid_token) { HmppsApi::Oauth::Token.new(access_token: access_token) }

  let(:auth_header) {
    {
      headers: {
        'Authorization': "Bearer #{access_token}"
      }
    }
  }

  before do
    allow(token_service).to receive(:valid_token).and_return(valid_token)
  end

  describe 'with a valid request' do
    it 'sets the Authorization header' do
      WebMock.stub_request(:get, /\w/).to_return(body: '{}')

      username = 'MOIC_POM'
      route = "/api/users/#{username}"
      client.get(route)

      expect(WebMock).to have_requested(:get, /\w/).
        with(auth_header)
    end
  end

  describe 'when there is an 404 (missing resource) error' do
    let(:error) do
      Faraday::ResourceNotFound.new('error', status: 401)
    end
    let(:offender_id) { '12344556' }
    let(:offender_no) { 'A1234AB' }
    let(:route)        {  "/elite2api/api/prisoners/#{offender_no}" }

    before do
      WebMock.stub_request(:get, /\w/).to_raise(error)
    end

    it 'raises an APIError', :raven_intercept_exception do
      expect { client.get(route) }.
        to raise_error(HmppsApi::Client::APIError, 'Unexpected status 401')
    end

    it 'sends the error to sentry' do
      expect(AllocationManager::ExceptionHandler).to receive(:capture_exception).with(error)
      expect { client.get(route) }.to raise_error(HmppsApi::Client::APIError)
    end

    it 'does not send the error to sentry if told not to' do
      non_logging_client = described_class.new(api_host, false)

      expect(AllocationManager::ExceptionHandler).not_to receive(:capture_exception).with(error)
      expect { non_logging_client.get(route) }.to raise_error(HmppsApi::Client::APIError)
    end
  end

  describe 'when there is an 500 (server broken) error' do
    let(:error) do
      Faraday::ClientError.new('error', status: 500)
    end
    let(:offender_no) { 'A1234AB' }
    let(:route)        { "/api/prisoners/#{offender_no}" }

    before do
      WebMock.stub_request(:get, /\w/).to_raise(error)
    end

    it 'raises an APIError', :raven_intercept_exception do
      expect { client.get(route) }.
        to raise_error(HmppsApi::Client::APIError, 'Client error: 500')
    end

    it 'sends the error to sentry' do
      expect(AllocationManager::ExceptionHandler).to receive(:capture_exception).with(error)
      expect { client.get(route) }.to raise_error(HmppsApi::Client::APIError)
    end
  end

  describe 'when the server is unreachable' do
    let(:error) do
      Faraday::ConnectionFailed.new('cannot connect')
    end
    let(:route)        { "/" }

    before do
      WebMock.stub_request(:get, /\w/).to_raise(error)
    end

    it 'raises an APIError', :raven_intercept_exception do
      broken_client = described_class.new('nosuchhost')

      expect { broken_client.get(route) }.
        to raise_error(HmppsApi::Client::APIError, 'Failed to connect to nosuchhost')
    end
  end

  describe 'instance method' do
    let(:route) { '/api/some/endpoint' }
    let(:stub_url) { api_host + route }
    let(:response_body) { '{"key": "value", "success": true}' }

    shared_examples 'handles JSON response' do
      it 'decodes the response JSON' do
        expect(response).to be_a(Hash)
        expect(response).to eq JSON.parse(response_body)
      end
    end

    describe '#get' do
      let(:response) do
        client.get(route)
      end

      before do
        WebMock.stub_request(:get, stub_url).
          to_return(body: response_body)

        # Trigger the request
        response
      end

      it 'performs an authenticated GET request' do
        expect(WebMock).to have_requested(:get, stub_url).
          with(auth_header)
      end

      include_examples 'handles JSON response'
    end

    describe '#post' do
      let(:request_body) { { id: 123, someKey: 'Some value' } }
      let(:response) do
        client.post(route, request_body)
      end

      before do
        WebMock.stub_request(:post, stub_url).
          to_return(body: response_body)

        # Trigger the request
        response
      end

      it 'performs an authenticated POST request' do
        expect(WebMock).to have_requested(:post, stub_url).
          with(auth_header)
      end

      it 'encodes the request body as JSON' do
        expect(WebMock).to have_requested(:post, stub_url).
          with(
            headers: {
              'Content-Type': 'application/json'
            },
            body: request_body.to_json
          )
      end

      include_examples 'handles JSON response'
    end

    describe '#put' do
      let(:request_body) { { id: 123, someKey: 'Some value' } }
      let(:response) do
        client.put(route, request_body)
      end

      before do
        WebMock.stub_request(:put, stub_url).
          to_return(body: response_body)

        # Trigger the request
        response
      end

      it 'performs an authenticated PUT request' do
        expect(WebMock).to have_requested(:put, stub_url).
          with(auth_header)
      end

      it 'encodes the request body as JSON' do
        expect(WebMock).to have_requested(:put, stub_url).
          with(
            headers: {
              'Content-Type': 'application/json'
            },
            body: request_body.to_json
          )
      end

      include_examples 'handles JSON response'
    end

    describe '#delete' do
      before do
        WebMock.stub_request(:delete, stub_url).
          to_return(status: 200)

        client.delete(route)
      end

      it 'performs an authenticated DELETE request' do
        expect(WebMock).to have_requested(:delete, stub_url).
          with(auth_header)
      end
    end
  end
end
