# frozen_string_literal: true
require 'fluent/plugin/filter'
require 'fluent/plugin/prometheus'
require 'yaml'

module Fluent::Plugin
  class QuotaThrottleFilter < Filter
    Fluent::Plugin.register_filter('quota_throttle', self)
    include Fluent::Plugin::PrometheusLabelParser
    include Fluent::Plugin::Prometheus
    helpers :event_emitter
    attr_reader :registry

    desc "Quota config file path for quota throttling"
    config_param :quota_config_path, :string, :default => nil

    desc "Used to group logs. Groups are rate limited independently"
    config_param :group_key, :array, :default => ['kubernetes.container_name']

    desc <<~DESC
      This is the period of of time over which group_bucket_limit applies
    DESC
    config_param :group_bucket_period_s, :integer, :default => 60

    desc <<~DESC
      Maximum number logs allowed per groups over the period of
      group_bucket_period_s
    DESC
    config_param :group_bucket_limit, :integer, :default => 6000

    desc "Whether to drop logs that exceed the bucket limit or not"
    config_param :group_drop_logs, :bool, :default => true

    desc <<~DESC
      When a group reaches its limit and as long as it is not reset, a warning
      message with the current log rate of the group is emitted repeatedly.
      This is the delay between every repetition.
    DESC
    config_param :group_warning_delay_s, :integer, :default => 10

    desc <<~DESC
      Whether to emit a metric when the rate limit is exceeded. The metric is fluentd_throttle_rate_limit_exceeded
    DESC
    config_param :enable_metrics, :bool, :default => false

    Group = Struct.new(
      :rate_count,
      :rate_last_reset,
      :aprox_rate,
      :bucket_count,
      :bucket_last_reset,
      :last_warning)

    def initialize
      super
      @registry = ::Prometheus::Client.registry
    end

    def configure(conf)
      super

      @group_key_paths = group_key.map { |key| key.split(".") }
      # Replace invalid characters with underscores and convert to symbols for valid labels
      @group_key_symbols = (group_key.map {|str| str.gsub(/[^a-zA-Z0-9_]/,'_')}).map(&:to_sym)

      raise "group_bucket_period_s must be > 0" \
        unless @group_bucket_period_s > 0

      @group_gc_timeout_s = 2 * @group_bucket_period_s

      raise "group_bucket_limit must be > 0" \
        unless @group_bucket_limit > 0

      raise "group_warning_delay_s must be >= 1" \
        unless @group_warning_delay_s >= 1

      if @enable_metrics
        hostname = Socket.gethostname
        expander_builder = Fluent::Plugin::Prometheus.placeholder_expander(log)
        expander = expander_builder.build({})
        @base_labels = parse_labels_elements(conf)
        @base_labels.each do |key, value|
          unless value.is_a?(String)
            raise Fluent::ConfigError, "record accessor syntax is not available in metric labels for throttle plugin"
          end
          @base_labels[key] = expander.expand(value)
        end
      end

      @quota = nil
      @quota = YAML.load(@quota_file)['quotas'] \
        if @quota_file != nil

      @secondary_tag_prefix = "secondary"

      @breach_tag_prefix = "breach"

      @cooldown_tag_prefix = "cooldown"
    end

    def start
      super

      @counters = {}
      # TODO add more relevant metrics to throttling
      @metrics = {throttle_rate_limit_exceeded: get_counter(:fluentd_throttle_rate_limit_exceeded, "The exceeded rate of pods in the group")}
    end

    def shutdown
      log.debug("counters summary: #{@counters}")
      super
    end

    def filter(tag, time, record)
      now = Time.now
      group = extract_group(record)

      # Ruby hashes are ordered by insertion.
      # Deleting and inserting moves the item to the end of the hash (most recently used)
      counter = @counters[group] = @counters.delete(group) || Group.new(0, now, 0, 0, now, nil)
      current_group_bucket_limit = @quota.find { |q| q["group"] = group} || @group_bucket_limit
      current_group_rate_limit = (current_group_bucket_limit / @group_bucket_period_s)
      counter.rate_count += 1
      since_last_rate_reset = now - counter.rate_last_reset
      if since_last_rate_reset >= 1
        # compute and store rate/s at most every second
        counter.aprox_rate = (counter.rate_count / since_last_rate_reset).round()
        counter.rate_count = 0
        counter.rate_last_reset = now
      end

      # try to evict the least recently used group
      lru_group, lru_counter = @counters.first
      if !lru_group.nil? && now - lru_counter.rate_last_reset > @group_gc_timeout_s
        @counters.delete(lru_group)
      end

      if (now.to_i / @group_bucket_period_s) \
          > (counter.bucket_last_reset.to_i / current_group_bucket_limit)
        # next time period reached.

        # wait until rate drops back down (if enabled).
        if counter.bucket_count == -1 and current_group_rate_limit != -1
          if counter.aprox_rate < current_group_rate_limit
            log_rate_back_down(now, group, counter, tag, time)
          else
            log_rate_limit_exceeded(now, group, counter, tag, time, record)
            return nil
          end
        end

        # reset counter for the rest of time period.
        counter.bucket_count = 0
        counter.bucket_last_reset = now
      else
        # if current time period credit is exhausted, drop the record.
        if counter.bucket_count == -1
          log_rate_limit_exceeded(now, group, counter, tag, time, record)
          return nil
        end
      end

      counter.bucket_count += 1

      # if we are out of credit, we drop logs for the rest of the time period.
      if counter.bucket_count > current_group_bucket_limit
        counter.bucket_count = -1
        log_rate_limit_exceeded(now, group, counter, tag, time, record)
        return nil
      end

      record
    end

    private

    def extract_group(record)
      @group_key_paths.map do |key_path|
        record.dig(*key_path) || record.dig(*key_path.map(&:to_sym))
      end
    end

    def log_rate_limit_exceeded(now, group, counter, tag, time, record)
      # Check if metrics are enabled
      if @enable_metrics
        # We create the new hash of label to label values for the metric
        groupped_label = @group_key_symbols.zip(group).to_h
        metric = @metrics[:throttle_rate_limit_exceeded]
        log.debug("current rate",counter.rate_count,"current metric",metric.get(labels: @base_labels.merge(groupped_label)))
        metric.increment(by: 1, labels: @base_labels.merge(groupped_label))
      end

      emit = counter.last_warning == nil ? true \
        : (now - counter.last_warning) >= @group_warning_delay_s
      if emit
        new_tag = breach+"."+tag
        breach_info = log_items(now, group, counter)
        router.emit(new_tag, time, breach_info)
        log.warn("rate exceeded", breach_info)
        counter.last_warning = now
      end

      if not @group_drop_logs
        new_tag = @secondary_tag_prefix + "." + tag
        router.emit(new_tag, time, record)
      end
    end

    def log_rate_back_down(now, group, counter, tag, time)
      new_tag = @cooldown_tag_prefix + "." + tag
      cooldown_info = log_items(now, group, counter)
      router.emit(new_tag, time, cooldown_info)
      log.info("rate back down", cooldown_info)
    end

    def log_items(now, group, counter, bucket_limit, rate_limit)
      since_last_reset = now - counter.bucket_last_reset
      rate = since_last_reset > 0 ? (counter.bucket_count / since_last_reset).round : Float::INFINITY
      aprox_rate = counter.aprox_rate
      rate = aprox_rate if aprox_rate > rate

      {'group_key': group,
       'rate_s': rate,
       'period_s': @group_bucket_period_s,
       'limit': bucket_limit,
       'rate_limit_s': rate_limit}
    end

    def get_counter(name, docstring)
      if @enable_metrics
        if @registry.exist?(name)
          @registry.get(name)
        else
          @registry.counter(name, docstring: docstring, labels: @base_labels.keys + @group_key_symbols)
        end
      end
    end
  end
end
