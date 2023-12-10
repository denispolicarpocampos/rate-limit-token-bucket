# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Middleware::TokenBucketLimit do
  let(:app) { ->(env) { [200, env, 'app'] } }
  let(:middleware) { described_class.new(app) }
  let(:request) { Rack::Request.new({}) }

  describe '#call' do
    context 'when the request is rate limited' do
      it 'returns a 429 response after exceeding the capacity' do
        threads = []
        results = []

        # Make enough requests to exceed the capacity
        #
        # We use threads here to simulate multiple concurrent requests to the server.
        # Each thread represents a separate request. By creating `CAPACITY + 1` threads,
        # we're making more requests than the token bucket capacity. This allows us to test
        # that the rate limiting functionality works correctly when the number of requests
        # exceeds the limit.
        (described_class::CAPACITY + 1).times do
          threads << Thread.new { results << middleware.call(request.env) }
        end

        threads.each(&:join)
        rate_limited_response = results.detect { |response| response[0] == 429 }

        expect(rate_limited_response[0]).to eq(429)
        expect(rate_limited_response[2]).to eq(['Too Many Requests'])
      end
    end

    context 'when the request is not rate limited' do
      it 'calls the next middleware or application in the stack' do
        response = middleware.call(request.env)

        expect(response[0]).to eq(200)
        expect(response[2]).to eq('app')
      end
    end
  end
end
