require 'fluent/plugin/filter'
require_relative './parser'
require_relative './matcher'
require_relative './rate_limiter'
module Fluent::Plugin
  class QuotaThrottleFilter < Filter
    Fluent::Plugin.register_filter('quota_throttle', self)

    desc "Path for the quota config file"
    config_param :path, :string, :default => nil

    def initialize
      super
    end

    def configure(conf)
      super
      @config = Parser::Configuration.new(@path)
      raise "quota config file should not be empty" \
        if @path.nil?
      @match_helper = Matcher::Match_Helper.new(@config.quotas, @config.default_quota)
    end

    def start
      super
      @bucket_store = RateLimiter::BucketStore.new
    end

    def shutdown
      super
      log.info "Shutting down"
    end

    def filter(tag, time, record)
      @bucket_store.clean_buckets
      quota = @match_helper.get_quota(record)
      group = quota.group_by.map { |key| record.dig(*key) }
      bucket = @bucket_store.get_bucket(group, quota)
      if bucket.allow
        record
      else
        quota_breached(bucket)
        nil
      end
    end

    private

    def quota_breached(bucket, quota)
      if bucket.last_warning.nil? || Time.now - bucket.last_warning > 60
        log.warn "Quota breached"
        bucket.last_warning = Time.now
      end

  end
end