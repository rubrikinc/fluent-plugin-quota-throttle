require_relative '../../helper'

class QuotaThrottleFilterTest < Minitest::Test
  include Fluent::Test::Helpers

  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    path test/config_files/filter_plugin_test.yml
    warning_delay 2m
    enable_metrics true
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::QuotaThrottleFilter).configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal "test/config_files/filter_plugin_test.yml", d.instance.path
    assert_equal 120, d.instance.warning_delay
  end

  def test_filter
    d = create_driver
    d.run(default_tag: 'test') do
      10.times do
        d.feed("group1" => { "a" => "value1" , "b" => "value2" })
        d.feed("group1" => { "a" => "value2" , "b" => "value3" })
        d.feed("group1" => { "a" => "value2" , "b" => "value2" })
        d.feed("group1" => { "a" => "value3" , "b" => "value2" })
      end
    end
    events = d.filtered_records
    assert_equal 23, events.length
  end

  def test_metrics
    d = create_driver
    d.run(default_tag: 'test') do
      10.times do
        d.feed("group1" => { "a" => "value1" , "b" => "value2" })
        d.feed("group1" => { "a" => "value2" , "b" => "value3" })
        d.feed("group1" => { "a" => "value2" , "b" => "value2" })
        d.feed("group1" => { "a" => "value3" , "b" => "value2" })
      end
    end
    assert_equal 10, d.instance.registry.get(:fluentd_quota_throttle_input).get(labels: {quota: 'quota1'})
    assert_equal 6, d.instance.registry.get(:fluentd_quota_throttle_filtered).get(labels: {quota: 'quota1'})
    assert_equal 10, d.instance.registry.get(:fluentd_quota_throttle_input).get(labels: {quota: 'quota2'})
    assert_equal 7, d.instance.registry.get(:fluentd_quota_throttle_filtered).get(labels: {quota: 'quota2'})
    assert_equal 20, d.instance.registry.get(:fluentd_quota_throttle_input).get(labels: {quota: 'default'})
    assert_equal 10, d.instance.registry.get(:fluentd_quota_throttle_filtered).get(labels: {quota: 'default'})
  end
end