require 'fluent/plugin/filter'
require_relative './parser'
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
    end

    def start
      super
    end

    def shutdown
      super
    end

    def filter(tag, time, record)
      record
    end

  end
end