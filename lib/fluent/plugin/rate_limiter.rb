##
# Rate Limiter module, contains the rate limiting logic
module RateLimiter

  ##
  # Bucket class, contains the rate limiting logic for each group
  # Attributes:
  #   +group+: Group for which the bucket is created
  #   +bucket_count+: Number of requests in the bucket
  #   +bucket_count_total+: Number of requests in the bucket including the dropped requests
  #   +bucket_last_reset+: Time when the bucket was last reset
  #   +approx_rate_per_second+: Approximate rate of requests per second
  #   +rate_last_reset+: Time when the rate was last reset
  #   +curr_count+: Number of requests in the current second
  #   +last_warning+: Time when the last warning was issued
  #   +timeout_s+: Timeout for the bucket
  #   +bucket_limit+: Maximum number of requests allowed in the bucket
  #   +bucket_period+: Time period for the bucket
  #   +rate_limit+: Maximum number of requests allowed per second
  #   +use_approx_rate_for_throttling+: Whether to use approximate rate for throttling
  class Bucket
    attr_accessor :bucket_count, :bucket_count_total, :bucket_last_reset, :approx_rate_per_second, :rate_last_reset, :curr_count, :last_warning
    attr_reader :bucket_limit, :bucket_period, :rate_limit, :timeout_s, :group, :use_approx_rate_for_throttling
    def initialize( group, bucket_limit, bucket_period, use_approx_rate_for_throttling=false)
      now = Time.now
      @group = group
      @bucket_count = 0
      @bucket_count_total = 0
      @bucket_last_reset = now
      @approx_rate_per_second = 0
      @rate_last_reset = now
      @curr_count = 0
      @last_warning = nil
      @bucket_limit = bucket_limit
      @bucket_period = bucket_period
      @rate_limit = bucket_limit/bucket_period
      @timeout_s = 2*bucket_period
      @use_approx_rate_for_throttling = use_approx_rate_for_throttling
    end

    # Checks if the bucket is free or full
    # Returns:
    #   +true+ if the bucket is free
    #   +false+ if the bucket is full
    def allow
      if @bucket_limit == -1
        return true
      end
      now = Time.now
      @curr_count += 1
      @bucket_count_total += 1
      time_lapsed = now - @rate_last_reset

      if time_lapsed.to_i >= 1
        @approx_rate_per_second = @curr_count / time_lapsed
        @rate_last_reset = now
        @curr_count = 0
      end

      if now.to_i / @bucket_period > @bucket_last_reset.to_i / @bucket_period
        reset_bucket
      end

      # Check if the bucket is already marked as full (-1) or has reached its limit
      if @bucket_count == -1 or @bucket_count >= @bucket_limit
        @bucket_count = -1
        return false
      else
        @bucket_count += 1
        return true
      end
    end

    # Checks if bucket is expired
    # Returns:
    #   +true+ if the bucket is expired
    #   +false+ if the bucket is not expired
    def expired
      now = Time.now
      now.to_i - @bucket_last_reset.to_i > @timeout_s
    end

    private

    # Resets the bucket when the window moves to the next time period
    def reset_bucket
      now = Time.now
      # If use_approx_rate_for_throttling is false, always reset the bucket
      # Otherwise, only reset if either: bucket is not marked as full (-1) OR rate is not exceeding the limit
      if !@use_approx_rate_for_throttling || !(@bucket_count == -1 && @approx_rate_per_second > @rate_limit)
        @bucket_count = 0
        @bucket_count_total = 0
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
      @buckets[[group, quota.name]] = @buckets.delete([group, quota.name]) || Bucket.new( group, quota.bucket_size, quota.duration, quota.use_approx_rate)
    end

    # Cleans the buckets that have expired
    def clean_buckets
      lru_group, lru_bucket = @buckets.first
      if !lru_group.nil? && lru_bucket.expired
        @buckets.delete(lru_group)
      end
    end
  end
end
