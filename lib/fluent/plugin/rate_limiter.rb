##
# Rate Limiter module, contains the rate limiting logic
module RateLimiter

  ##
  # Bucket class, contains the rate limiting logic for each group
  # Attributes:
  #   +bucket_count+: Number of requests in the bucket
  #   +bucket_last_reset+: Time when the bucket was last reset
  #   +approx_rate_per_second+: Approximate rate of requests per second
  #   +rate_last_reset+: Time when the rate was last reset
  #   +curr_count+: Number of requests in the current second
  #   +last_warning+: Time when the last warning was issued
  #   +timeout_s+: Timeout for the bucket
  #   +bucket_limit+: Maximum number of requests allowed in the bucket
  #   +bucket_period+: Time period for the bucket
  #   +rate_limit+: Maximum number of requests allowed per second
  class Bucket
    attr_accessor :bucket_count, :bucket_last_reset, :approx_rate_per_second, :rate_last_reset, :curr_count, :last_warning
    attr_reader :bucket_limit, :bucket_period, :rate_limit, :timeout_s
    def initialize( bucket_limit, bucket_period)
      now = Time.now
      @bucket_count = 0
      @bucket_last_reset = now
      @approx_rate_per_second = 0
      @rate_last_reset = now
      @curr_count = 0
      @last_warning = nil
      @bucket_limit = bucket_limit
      @bucket_period = bucket_period
      @rate_limit = bucket_limit/bucket_period
      @timeout_s = 2*bucket_period
    end

    # Checks if the bucket is free or full
    # Returns:
    #   +true+ if the bucket is free
    #   +false+ if the bucket is full
    def allow
      now = Time.now
      @curr_count += 1
      time_lapsed = now - @rate_last_reset

      if time_lapsed.to_i >= 1
        @approx_rate_per_second = @curr_count / time_lapsed
        @rate_last_reset = now
        @curr_count = 0
      end

      if now.to_i / @bucket_period > @bucket_last_reset.to_i / @bucket_period
        reset_bucket
      end

      if @bucket_count == -1 or @bucket_count > @bucket_limit
        @bucket_count = -1
        return false
      else
        @bucket_count += 1
        true
      end
    end

    private

    # Resets the bucket when the window moves to the next time period
    def reset_bucket
      now = Time.now
      unless @bucket_count == -1 && @approx_rate_per_second > @rate_limit
        @bucket_count = 0
        @bucket_last_reset = now
      end
    end
  end

  ##
  # BucketStore class, organizes the all the group buckets
  # Attributes:
  #   +buckets+: Hash containing all the group buckets
  class BucketStore
    def initialize
      @buckets = {}
    end

    # Gets the bucket for the group
    # Arguments:
    #   +group+: Group for which the bucket is required
    #   +quota+: Quota object containing the bucket size and duration
    def get_bucket(group, quota)
      now = Time.now
      @buckets[group] = @buckets.delete(group) || Bucket.new( quota.bucket_size, quota.duration)
    end

    # Cleans the buckets that have expired
    def clean_buckets
      now = Time.now
      lru_group, lru_bucket = @buckets.first
      puts now - lru_bucket.rate_last_reset
      if !lru_group.nil? && now.to_i - lru_bucket.rate_last_reset.to_i > lru_bucket.timeout_s
        @buckets.delete(lru_group)
      end
    end
  end
end