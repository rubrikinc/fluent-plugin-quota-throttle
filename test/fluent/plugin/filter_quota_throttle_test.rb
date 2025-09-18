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

  def test_fallback_quota_functionality
    d = create_driver

    # Test fallback quota behavior
    d.run(default_tag: 'test') do
      # Send records that match the fallback quota
      # Primary quota allows 3 records, fallback allows 2 more
      8.times do |i|
        d.feed("group1" => { "a" => "value_fallback", "b" => "test_value" })
      end
    end

    events = d.filtered_records

    # Should allow 3 (primary) + 2 (fallback) = 5 records total
    # The remaining 3 records should be dropped
    assert_equal 5, events.length

    # Verify all allowed records have the expected structure
    events.each do |record|
      assert_equal "value_fallback", record["group1"]["a"]
      assert_equal "test_value", record["group1"]["b"]
    end
  end

  def test_fallback_quota_with_different_groups
    d = create_driver

    # Test that fallback quota works correctly with truly different groups
    d.run(default_tag: 'test') do
      # Group 1: quota_fallback (3 primary + 2 fallback = 5 max)
      # Send 6 records, expect 5 to pass
      6.times do |i|
        d.feed("group1" => { "a" => "value_fallback", "b" => "group_1_record_#{i}" })
      end

      # Group 2: quota_fallback_2 (2 primary + 1 fallback = 3 max)
      # Send 4 records, expect 3 to pass
      4.times do |i|
        d.feed("group1" => { "a" => "value_fallback_2", "b" => "group_2_record_#{i}" })
      end
    end

    events = d.filtered_records

    # Total: 5 (from group 1) + 3 (from group 2) = 8 records
    assert_equal 8, events.length

    # Count records by group
    group_1_count = events.count { |r| r["group1"]["a"] == "value_fallback" }
    group_2_count = events.count { |r| r["group1"]["a"] == "value_fallback_2" }

    assert_equal 5, group_1_count  # 3 primary + 2 fallback
    assert_equal 3, group_2_count  # 2 primary + 1 fallback
  end

  def test_non_fallback_quota_behavior_unchanged
    d = create_driver

    # Test that non-fallback quotas still work as expected
    d.run(default_tag: 'test') do
      # Send records that match quota1 (drop action, bucket_size: 5)
      10.times do
        d.feed("group1" => { "a" => "value1", "b" => "test" })
      end
    end

    events = d.filtered_records

    # Should allow exactly 5 records (no fallback for quota1)
    assert_equal 5, events.length
  end
end