require 'fluent/plugin/filter'
require_relative './parser'
require_relative './matcher'
require_relative './rate_limiter'

##
# Fluentd plugin that filters records based on quotas
module Fluent::Plugin

  ##
  # QuotaThrottleFilter class is derived from the Filter class and is responsible for filtering records based on quotas
  class QuotaThrottleFilter < Filter
    Fluent::Plugin.register_filter('quota_throttle', self)
    helpers :event_emitter

    desc "Path for the quota config file"
    config_param :path, :string, :default => nil

    desc "Delay in seconds between warnings for the same group when the quota is breached"
    config_param :warning_delay, :integer, :default => 60

    def initialize
      @reemit_tag_suffix = "secondary"
      super
    end

    # Configures the plugin
    def configure(conf)
      super
      raise "quota config file should not be empty" \
        if @path.nil?
      @config = ConfigParser::Configuration.new(@path)
      @match_helper = Matcher::MatchHelper.new(@config.quotas, @config.default_quota)
    end

    def start
      super
      @bucket_store = RateLimiter::BucketStore.new
    end

    def shutdown
      super
      log.info "Shutting down"
    end

    ##
    # Filters records based on quotas
    # Params:
    #   +tag+: (String) The tag of the record
    #   +time+: (Time) The timestamp of the record
    #   +record+: (Hash) The record to filter
    def filter(tag, time, record)
      @bucket_store.clean_buckets
      quota = @match_helper.get_quota(record)
      group = quota.group_by.map { |key| record.dig(*key) }
      bucket = @bucket_store.get_bucket(group, quota)
      if bucket.allow
        record
      else
        quota_breached(bucket, quota, time)
        nil
      end
    end

    private

    # Logs a warning and takes the action specified in the quota
    # Params:
    #   +bucket+: (Bucket) The bucket that has breached the quota
    #   +quota+: (Quota) The quota that has been breached
    #   +timestamp+: (Time) The timestamp of the record
    def quota_breached(bucket, quota, timestamp)
      if bucket.last_warning.nil? || Time.now - bucket.last_warning > @warning_delay
        log.warn "Quota breached for group #{bucket.group} in quota #{quota.name}"
        bucket.last_warning = Time.now
      end
      case quota.action
      when "drop"
        log.debug "Dropping record"
      when "reemit"
        log.debug "Reemitting record"
        new_tag = "#{tag}.#{@reemit_tag_suffix}"
        router.emit(new_tag, timestamp, record)
      end
    end
  end
end