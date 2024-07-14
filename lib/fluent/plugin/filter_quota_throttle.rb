require 'fluent/plugin/filter'
require 'fluent/plugin/prometheus'
require_relative 'config_parser'
require_relative 'matcher'
require_relative 'rate_limiter'

##
# Fluentd plugin that filters records based on quotas
module Fluent::Plugin

  ##
  # QuotaThrottleFilter class is derived from the Filter class and is responsible for filtering records based on quotas
  class QuotaThrottleFilter < Filter
    Fluent::Plugin.register_filter('quota_throttle', self)
    include Fluent::Plugin::PrometheusLabelParser
    include Fluent::Plugin::Prometheus
    attr_reader :registry

    desc "Path for the quota config file"
    config_param :path, :string, :default => nil

    desc "Delay in seconds between warnings for the same group when the quota is breached"
    config_param :warning_delay, :time, :default => 60

    desc "Enable prometheus metrics"
    config_param :enable_metrics, :bool, :default => false

    def initialize
      super
      @reemit_tag_prefix = "secondary"
      @registry = ::Prometheus::Client.registry
      @placeholder_expander_builder = Fluent::Plugin::Prometheus.placeholder_expander(log)
    end

    # Configures the plugin
    def configure(conf)
      super
      raise "quota config file should not be empty" \
        if @path.nil? or !File.exist?(@path)
      raise "Warning delay should be non negative" \
        if @warning_delay < 0
      parsed_config = ConfigParser::Configuration.new(@path)
      @match_helper = Matcher::MatchHelper.new(parsed_config.quotas, parsed_config.default_quota)
      if @enable_metrics
        @base_labels = parse_labels_elements(conf)
      end
    end

    def start
      super
      @bucket_store = RateLimiter::BucketStore.new
      if @enable_metrics
        @metrics = {
           quota_input: get_counter(:fluentd_quota_throttle_input, "Number of records entering quota throttle plugin"),
           quota_exceeded: get_counter(:fluentd_quota_throttle_exceeded, "Number of records exceeded the quota"),
        }
      end
    end

    def shutdown
      super
      if @enable_metrics
        log.info "Clearing Counters"
        @metrics.each do |name, metric|
          @registry.unregister(name)
        end
      end
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
      labels = {}
      if @enable_metrics
        labels = get_labels(record)
        @metrics[:quota_input].increment(by: 1, labels: labels.merge({quota: quota.name}))
      end
      if bucket.allow
        record
      else
        if @enable_metrics
          @metrics[:quota_exceeded].increment(by: 1, labels: labels.merge({quota: quota.name}))
        end
        quota_breached(tag, time, record, bucket, quota)
        nil
      end
    end

    private

    # Logs a warning and takes the action specified in the quota
    # Params:
    #   +bucket+: (Bucket) The bucket that has breached the quota
    #   +quota+: (Quota) The quota that has been breached
    #   +timestamp+: (Time) The timestamp of the record
    def quota_breached(tag, timestamp, record, bucket, quota)
      if bucket.last_warning.nil? || Time.now - bucket.last_warning > @warning_delay
        log.warn "Quota breached for group #{bucket.group} in quota #{quota.name}"
        bucket.last_warning = Time.now
      end
      case quota.action
      when "drop"
        log.debug "Dropping record"
      when "reemit"
        log.debug "Reemitting record"
        new_tag = "#{@reemit_tag_prefix}.#{tag}"
        router.emit(new_tag, timestamp, record)
      end
    end

    def get_labels(record)
      placeholders = stringify_keys(record)
      expander = @placeholder_expander_builder.build(placeholders)
      labels = {}
      @base_labels.each do |key, value|
        if value.is_a?(String)
          labels[key] = expander.expand(value)
        elsif value.respond_to?(:call)
          labels[key] = value.call(record)
        end
      end
      labels
    end
    
    def get_counter(name, docstring)
      if @registry.exist?(name)
        @registry.get(name)
      else
        @registry.counter(name, docstring: docstring, labels: @base_labels.keys + ["quota"].map(&:to_sym))
      end
    end
  end
end