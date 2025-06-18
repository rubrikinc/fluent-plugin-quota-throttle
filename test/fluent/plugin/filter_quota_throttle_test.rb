require_relative '../../helper'

class QuotaThrottleFilterTest < Minitest::Test
  include Fluent::Test::Helpers

  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    path test/config_files/filter_plugin_test.yml
    warning_delay 2m
    enable_metrics false
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
    assert_equal 19, events.length
  end

  # Due to the way the Driver is implemented, both metrics tests cannot be same time because the registry of metrics is not cleared between tests
  # def test_metrics_without_labels
  #   modified_config = CONFIG.sub("enable_metrics false", "enable_metrics true")
  #   d = create_driver(modified_config)
  #   d.run(default_tag: 'test') do
  #     10.times do
  #       d.feed("group1" => { "a" => "value1" , "b" => "value2" })
  #       d.feed("group1" => { "a" => "value2" , "b" => "value3" })
  #       d.feed("group1" => { "a" => "value2" , "b" => "value2" })
  #       d.feed("group1" => { "a" => "value3" , "b" => "value2" })
  #     end
  #   end
  #   assert_equal 10, d.instance.registry.get(:fluentd_quota_throttle_input).get(labels: {quota: 'quota1'})
  #   assert_equal 4, d.instance.registry.get(:fluentd_quota_throttle_exceeded).get(labels: {quota: 'quota1'})
  #   assert_equal 10, d.instance.registry.get(:fluentd_quota_throttle_input).get(labels: {quota: 'quota2'})
  #   assert_equal 3, d.instance.registry.get(:fluentd_quota_throttle_exceeded).get(labels: {quota: 'quota2'})
  #   assert_equal 20, d.instance.registry.get(:fluentd_quota_throttle_input).get(labels: {quota: 'default'})
  #   assert_equal 10, d.instance.registry.get(:fluentd_quota_throttle_exceeded).get(labels: {quota: 'default'})
  # end
  def test_metrics_with_labels
    labels = %[
        <labels>
          source $.group1.a
          dummy d1
        </labels>
    ]
    modified_config = CONFIG.sub("enable_metrics false", "enable_metrics true" + labels)
    d = create_driver(modified_config)
    d.run(default_tag: 'test') do
      10.times do
        d.feed("group1" => { "a" => "value1" , "b" => "value2" })
        d.feed("group1" => { "a" => "value2" , "b" => "value3" })
        d.feed("group1" => { "a" => "value2" , "b" => "value2" })
        d.feed("group1" => { "a" => "value3" , "b" => "value2" })
      end
    end
    assert_equal 10, d.instance.registry.get(:fluentd_quota_throttle_input).get(labels: {source: "value1", quota: 'quota1', dummy: 'd1'})
    assert_equal 5, d.instance.registry.get(:fluentd_quota_throttle_exceeded).get(labels: {source: "value1", quota: 'quota1', dummy: 'd1'})
    assert_equal 10, d.instance.registry.get(:fluentd_quota_throttle_input).get(labels: {source: "value2", quota: 'quota2', dummy: 'd1'})
    assert_equal 4, d.instance.registry.get(:fluentd_quota_throttle_exceeded).get(labels: {source: "value2", quota: 'quota2', dummy: 'd1'})
    assert_equal 10, d.instance.registry.get(:fluentd_quota_throttle_input).get(labels: {source: "value2", quota: 'default', dummy: 'd1'})
    assert_equal 6, d.instance.registry.get(:fluentd_quota_throttle_exceeded).get(labels: {source: "value2", quota: 'default', dummy: 'd1'})
    assert_equal 10, d.instance.registry.get(:fluentd_quota_throttle_input).get(labels: {source: "value3", quota: 'default', dummy: 'd1'})
    assert_equal 6, d.instance.registry.get(:fluentd_quota_throttle_exceeded).get(labels: {source: "value3", quota: 'default', dummy: 'd1'})
  end

  def test_filter_without_approx_rate_throttling
    # Use config with approx rate throttling disabled
    config_without_throttling = %[
      path test/config_files/filter_plugin_test.yml
      warning_delay 2m
      enable_metrics false
    ]
    
    d = create_driver(config_without_throttling)
    
    # First batch - fill up the buckets
    d.run(default_tag: 'test') do
      # Send enough records to fill quota
      100.times do
        d.feed("group1" => { "a" => "value4", "b" => "value5" })
      end
      
      # Sleep for longer than the bucket duration
      sleep(10)
      
      # Send more records to fill quota
      4.times do
        d.feed("group1" => { "a" => "value4", "b" => "value5" })
      end
    end
    
    # Verify that quota is filled, as buckets are reset regardless of rate
    assert_equal 9, d.filtered_records.length
  end

  def test_filter_with_approx_rate_throttling
    # Use config with approx rate throttling enabled
    config_without_throttling = %[
      path test/config_files/filter_plugin_test.yml
      warning_delay 2m
      enable_metrics false
    ]
    
    d = create_driver(config_without_throttling)
    
    # First batch - fill up the buckets
    d.run(default_tag: 'test') do
      # Send enough records to fill quota
      100.times do
        d.feed("group1" => { "a" => "value5", "b" => "value6" })
      end
      
      # Sleep for longer than the bucket duration
      sleep(10)
      
      # Send more records to fill quota
      4.times do
        d.feed("group1" => { "a" => "value5", "b" => "value6" })
      end
    end
    
    # Verify that quota is not filled, as buckets are not reset due to high rate
    assert_equal 5, d.filtered_records.length
  end
end