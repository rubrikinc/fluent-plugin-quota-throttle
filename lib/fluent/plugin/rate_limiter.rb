module RateLimiter
  class Bucket
    attr_accessor :bucket_count, :bucket_last_reset, :approx_rate_per_second, :rate_last_reset, :curr_count, :last_warning, :timeout_s
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

    def allow
      # Returns true if the bucket is free
      # Returns false if the bucket is full
      now = Time.now
      @curr_count += 1
      time_lapsed = now - @rate_last_reset

      if time_lapsed >= 1
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

    def reset_bucket
      # Does necessary processing when window moves to next time period
      now = Time.now
      unless @bucket_count == -1 && @approx_rate_per_second > @rate_limit
        @bucket_count = 0
        @bucket_last_reset = now
      end
    end
  end

  class BucketStore
    def initialize
      @counters = {}
    end

    def get_counter(group, quota)
      now = Time.now
      @counters[group] = @counters.delete(group) || Bucket.new(0, now, 0, 0, now, nil, quota.bucket_size, quota.duration)
    end

    def clean_counters
      now = Time.now
      lru_group, lru_counter = @counters.first
      if !lru_group.nil? && now.to_i - lru_counter.rate_last_reset > lru_counter.timeout_s
        @counters.delete(lru_group)
      end
    end
  end
end