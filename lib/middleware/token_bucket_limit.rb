# frozen_string_literal: true

module Middleware
  # TokenBucketLimit middleware implements token bucket rate limiting.
  # It allows a certain number of requests to be processed per second,
  # while rejecting additional requests beyond the limit.
  #
  # The rate limiting is controlled by a token bucket for each IP address.
  # Each bucket has a maximum capacity of tokens (CAPACITY), and new tokens
  # are added to the bucket at a certain rate (REFILL_RATE) every second.
  #
  # When a request comes in, a token is removed from the bucket. If the bucket
  # is empty, the request is rate-limited. Over time, as new tokens are added,
  # the IP address can make additional requests.
  #
  # This approach allows for bursty traffic (up to the bucket capacity), while
  # still limiting the overall request rate.
  #
  # @param app [Object] The next middleware or application in the stack.
  class TokenBucketLimit
    REFILL_RATE = 1 # 1 token per second
    CAPACITY = 10 # 10 tokens per second

    def initialize(app)
      @app = app
      @mutex = Mutex.new
      @token_buckets ||= Hash.new { |h, k| h[k] = { tokens: CAPACITY, last_refreshed: Time.now.to_i } }
    end

    # The `call` method is invoked for each incoming HTTP request.
    #
    # This method is part of the Rack middleware interface. It checks if the incoming
    # request should be rate-limited based on the Token Bucket algorithm. If the request
    # is rate-limited, it returns a 429 'Too Many Requests' response. If the request is
    # not rate-limited, it forwards the request to the next middleware in the stack.
    def call(env)
      request = Rack::Request.new(env)

      return too_many_requests_response if rate_limited?(request)

      @app.call(env)
    end

    private

    def too_many_requests_response
      [429, { 'Content-Type' => 'text/plain' }, ['Too Many Requests']]
    end

    # Determines if a request should be rate-limited based on the IP address.
    #
    # This method uses the Token Bucket algorithm to control the rate of requests.
    # Each IP address has a "bucket" of tokens, which are consumed by requests.
    # When the bucket is empty, further requests are rate-limited until tokens are refilled.
    # If the number of tokens is less than 1, the method returns true, indicating that the request should be rate-limited.
    #
    # @param request [Rack::Request] The incoming request.
    # @return [Boolean] Returns true if the request is rate-limited (i.e., the bucket is empty)
    def rate_limited?(request)
      ip = request.ip
      token_bucket = nil

      # We use a Mutex (@mutex) to ensure thread-safety when accessing the
      # @token_buckets hash in a multi-threaded context.
      @mutex.synchronize do
        token_bucket = @token_buckets[ip]
        refill_tokens(token_bucket)

        return true if token_bucket[:tokens] < 1

        token_bucket[:tokens] -= 1
      end

      false
    end

    # Refills tokens in the bucket based on the time elapsed since the last request.
    #
    # This method is part of the Token Bucket algorithm used for rate limiting.
    # It calculates the number of tokens to be refilled based on the time elapsed
    # since the last request was made. The refill rate is defined by the REFILL_RATE constant.
    # If the refill amount would cause the number of tokens to exceed the bucket's capacity,
    # the number of tokens is set to the capacity.
    #
    # @param token_bucket [Hash] The token bucket associated with a specific IP address.
    #                            The bucket contains the number of tokens and the time it was last refreshed.
    def refill_tokens(token_bucket)
      current_time = Time.now.to_i
      elapsed_time = current_time - token_bucket[:last_refreshed]
      refill_amount = elapsed_time * REFILL_RATE

      token_bucket[:tokens] = [token_bucket[:tokens] + refill_amount, CAPACITY].min
      token_bucket[:last_refreshed] = current_time
    end
  end
end
