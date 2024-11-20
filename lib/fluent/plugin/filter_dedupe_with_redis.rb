require 'fluent/plugin/filter'
require 'fluent/plugin/prometheus'
require 'digest/md5'
require 'redis'

module Fluent::Plugin
  class DedupeWithRedisFilter < Fluent::Plugin::Filter
    Fluent::Plugin.register_filter('dedupe_with_redis', self)
    include Fluent::Plugin::PrometheusLabelParser
    include Fluent::Plugin::Prometheus

    config_param :fields, :array, value_type: :string,
                desc: "List of fields to use for deduplication"

    config_param :redis_host, :string, default: 'localhost',
                desc: "Redis server hostname"

    config_param :redis_port, :integer, default: 6379,
                desc: "Redis server port"

    config_param :redis_user, :string, default: nil,
                desc: "Redis username"

    config_param :redis_password, :string, default: nil,
                desc: "Redis password"

    config_param :ttl, :integer, default: 300,
                desc: "Time-to-live for keys in seconds"

    config_param :enable_metrics, :bool, default: false,
                desc: "Enable prometheus metrics"

    config_param :drop_duplicates, :bool, default: true,
                desc: "Indicates whether to drop or re-tag duplicate log lines"

    config_param :bucket_size, :integer, default: 1000000,
                desc: "Count of log lines exceeding this number will pass through without dedupe"

    attr_reader :registry

    def initialize
      super
      @redis = nil
      @metrics = {}
      @registry = ::Prometheus::Client.registry
      @placeholder_expander_builder = Fluent::Plugin::Prometheus.placeholder_expander(log)
    end

    def configure(conf)
      super
      begin
        @redis = Redis.new(
          host: @redis_host,
          port: @redis_port,
          username: @redis_user,
          password: @redis_password
        )
        # Test the connection at startup
        @redis.ping
      rescue => e
        log.error "Redis connection failed: #{e.message}"
        @redis = nil
      end

      if @enable_metrics
        @base_labels = parse_labels_elements(conf)
      end
    end

    def start
      super
      log.info "DedupeWithRedisFilter plugin has started."

      if @enable_metrics
        @metrics = {
          # assert input = deduped_count + output
          dedupe_input: get_counter(:fluentd_dedupe_plugin_input, "Number of records entering dedupe plugin"),
          deduped_count: get_counter(:fluentd_dedupe_count, "Number of records de-duplicated"),
          deduped_output: get_counter(:fluentd_dedupe_plugin_output, "Number of records passed-through from plugin")
        }
      end
    end

    def filter(tag, time, record)
      begin
        labels = {}
        # check_and_emit_metric(tag, time, record, @metrics[:dedupe_input], 1, labels)
        if @enable_metrics
          labels = get_labels(record)
          @metrics[:dedupe_input].increment(by: 1, labels: labels)
        end

        # Skip deduplication if Redis connection failed
        return record unless @redis

        # Initialize the digest for this log line
        digest = Digest::MD5.new

        # Update the digest incrementally with each field's value if the field exists
        @fields.each do |field|
          value = get_nested_field(record, field)
          digest.update(value.to_s) unless value.nil?
        end

        # Finalize the digest computation to get the hash
        key = digest.hexdigest

        count = @redis.get(key)
        if count
          count = count.to_i
          if count < @bucket_size
            # Ensure TTL is at least 1 if it's -1 (no expire) or -2 (key doesn't exist)
            key_ttl = @redis.ttl(key)
            key_ttl = [key_ttl, 1].max
            @redis.set(key, (count + 1).to_s, ex: key_ttl)
            @metrics[:deduped_count].increment(labels: labels) if @enable_metrics

            if @drop_duplicates
              return nil
            else
              # Re-tagging and emitting the record with the new tag
              new_tag = "dedupe.#{tag}"
              router.emit(new_tag, time, record)
              return nil  # Return nil to prevent the original record from being emitted
            end
          else
              # If count >= bucket_size, let the record pass through
              @metrics[:deduped_output].increment(labels: labels) if @enable_metrics
              return record
          end
        else
          # First occurrence of this record
          @redis.set(key, "1", ex: @ttl)
          @metrics[:deduped_output].increment(labels: labels) if @enable_metrics
          return record
        end
      rescue => e
        log.error "Redis operation failed: #{e.message}"
        log.error_backtrace
        @metrics[:deduped_output].increment(labels: labels) if @enable_metrics
        return record  # Continue processing without deduplication
      end
    end

    def shutdown
      super
      log.info "DedupeWithRedisFilter plugin is shutting down."

      if @redis
        log.info "Closing redis instance"
        @redis.close rescue nil
      end

      if @enable_metrics
        log.info "Clearing Counters"
        @metrics.each do |name, metric|
          @registry.unregister(name) rescue nil
        end
      end

      log.info "Shutdown complete"
    end

    private

    def get_nested_field(record, field)
      return nil if field.nil? || record.nil?

      keys = field.split('.')
      value = record

      keys.each do |key|
        return nil unless value.is_a?(Hash) && value.key?(key)
        value = value[key]
      end

      value
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
        @registry.counter(name, docstring: docstring, labels: @base_labels.keys)
      end
    end

    def check_and_emit_metric(tag, time, record, metric, increment_value, labels)
        if @enable_metrics
            labels ||= get_labels(record) if labels.nil
            metric.increment(by: increment_value, label: labels)
        end
    end
  end
end

