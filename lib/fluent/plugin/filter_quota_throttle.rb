require 'fluent/plugin/filter'
require_relative './parser'
module Fluent::Plugin
  class QuotaThrottleFilter < Filter
    Fluent::Plugin.register_filter('quota_throttle', self)

    desc "Path for the quota config file"
    config_param :path, :string, :default => nil

    Group = Struct.new(:bucket_count,:bucket_last_reset,:approx_rate,:rate_last_reset,:curr_count,:last_warning)
    def initialize
      super
    end

    def configure(conf)
      super
      @config = Parser::Configuration.new(@path)
      raise "quota config file should not be empty" \
        if @path.nil?
    end

    def start
      super
      @counters = {}
    end

    def shutdown
      super
    end

    def filter(tag, time, record)
      record
    end

  end
end