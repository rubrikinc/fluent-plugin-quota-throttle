require_relative '../../helper'

class DedupeWithRedisFilterTest < Test::Unit::TestCase
  include Fluent::Test::Helpers
  
  setup do
    Fluent::Test.setup
    @mock_redis = mock('redis')
    Redis.stubs(:new).returns(@mock_redis)
    @mock_redis.stubs(:close)
    @mock_redis.stubs(:ping)

    @default_config = %[
      @type dedupe_with_redis
      fields ["field1", "nested.field2"]
      redis_host localhost
      redis_port 6379
      ttl 300
      enable_metrics false
      drop_duplicates true
      bucket_size 3
    ]

    @sample_record = {
      'field1' => 'value1',
      'nested' => { 'field2' => 'value2' },
      'message' => 'test'
    }
  end

  def create_driver(conf)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::DedupeWithRedisFilter).configure(conf)
  end

  sub_test_case 'configuration' do
    test 'basic configuration' do
      d = create_driver(@default_config)
      assert_equal ['field1', 'nested.field2'], d.instance.fields
      assert_equal 'localhost', d.instance.redis_host
      assert_equal 6379, d.instance.redis_port
      assert_equal 300, d.instance.ttl
      assert_equal false, d.instance.enable_metrics
      assert_equal true, d.instance.drop_duplicates
    end

    test 'missing fields parameter' do
      assert_raise(Fluent::ConfigError) do
        create_driver(%[
          redis_host localhost
          redis_port 6379
          ttl 300
        ])
      end
    end

    test 'with redis credentials' do
      conf = @default_config + %[
        redis_user testuser
        redis_password testpass
      ]
      d = create_driver(conf)
      assert_equal 'testuser', d.instance.redis_user
      assert_equal 'testpass', d.instance.redis_password
    end
  end

  sub_test_case 'filtering' do
    test 'new record' do
      @mock_redis.expects(:get).returns(nil)
      @mock_redis.expects(:set).with(instance_of(String), "1", ex: 300).returns("OK")

      d = create_driver(@default_config)
      time = event_time("2024-01-01 00:00:00 UTC")

      d.run(default_tag: 'test') do
        d.feed(time, @sample_record)
      end

      filtered_records = d.filtered_records
      assert_equal 1, filtered_records.length
      assert_equal 'value1', filtered_records[0]['field1']
      assert_equal 'value2', filtered_records[0]['nested']['field2']
      assert_equal 'test', filtered_records[0]['message']
    end

    test 'duplicate record' do
      remaining_ttl = 200
      @mock_redis.expects(:get).returns("1")
      @mock_redis.expects(:set).with(instance_of(String), "2", ex: remaining_ttl).returns("OK")
      @mock_redis.expects(:ttl).returns(remaining_ttl)

      d = create_driver(@default_config)
      time = event_time("2024-01-01 00:00:00 UTC")

      d.run(default_tag: 'test') do
        d.feed(time, @sample_record)
      end

      filtered_records = d.filtered_records
      assert_equal 0, filtered_records.length
    end

    test 'missing nested fields' do
      @mock_redis.expects(:get).returns(nil)
      @mock_redis.expects(:set).with(instance_of(String), "1", ex: 300).returns("OK")

      d = create_driver(@default_config)
      time = event_time("2024-01-01 00:00:00 UTC")
      record_with_missing_field = {
        'field1' => 'value1'
        # missing 'nested.field2' field
      }

      d.run(default_tag: 'test') do
        d.feed(time, record_with_missing_field)
      end

      filtered_records = d.filtered_records
      assert_equal 1, filtered_records.length
    end

    test 'multiple records with same fields' do
      # First record: Redis does not have the key, create new one
      remaining_ttl = 200
      @mock_redis.expects(:ttl).with(instance_of(String)).returns(remaining_ttl)

      @mock_redis.expects(:get).returns(nil)
      @mock_redis.expects(:set).with(instance_of(String), "1", ex: 300).returns("OK")

      # Second record: Redis has the key, increment
      @mock_redis.expects(:get).returns("1")
      @mock_redis.expects(:set).with(instance_of(String), "2", ex: remaining_ttl).returns("OK")

      d = create_driver(@default_config)
      time = event_time("2024-01-01 00:00:00 UTC")

      d.run(default_tag: 'test') do
        2.times do |i|
          record = @sample_record.merge('count' => i)
          d.feed(time, record)
        end
      end

      filtered_records = d.filtered_records
      assert_equal 1, filtered_records.length  # First record should pass through, second should be filtered out
    end

    test 'duplicate logs exceeding bucket count' do
      # First record: Redis does not have the key, create new one
      @mock_redis.expects(:get).returns(nil)
      @mock_redis.expects(:set).with(instance_of(String), "1", ex: 300).returns("OK")

      # Second record: Redis has the key, increment
      @mock_redis.expects(:get).returns("1")
      @mock_redis.expects(:set).with(instance_of(String), "2", ex: 200).returns("OK")

      @mock_redis.expects(:get).returns("2")
      @mock_redis.expects(:set).with(instance_of(String), "3", ex: 100).returns("OK")

      @mock_redis.expects(:get).returns("3")

      @mock_redis.expects(:ttl).returns(200)
      @mock_redis.expects(:ttl).returns(100)

      d = create_driver(@default_config)
      time = event_time("2024-01-01 00:00:00 UTC")

      d.run(default_tag: 'test') do
        4.times do |i|
          record = @sample_record.merge('count' => i)
          d.feed(time, record)
        end
      end

      filtered_records = d.filtered_records
      # First record should pass through, second, third should be filtered out, fourth should pass through
      assert_equal 2, filtered_records.length
      
      assert_equal @sample_record.merge('count' => 0), filtered_records[0]
      assert_equal @sample_record.merge('count' => 3), filtered_records[1]
    end
  end

  sub_test_case 'redis operations' do
    test 'successful redis initialization' do
      @mock_redis.expects(:ping).returns("PONG")
      d = create_driver(@default_config)
      assert_nothing_raised do
        d.instance.start
      end
    end

    test 'failed redis initialization' do
      Redis.unstub(:new)
      Redis.expects(:new).raises(Redis::CannotConnectError)

      d = create_driver(@default_config)
      assert_nothing_raised do
        d.instance.start
      end
    end

    test 'redis connection failure' do
      @mock_redis.expects(:get).raises(Redis::CannotConnectError)

      d = create_driver(@default_config)
      time = event_time("2024-01-01 00:00:00 UTC")

      d.run(default_tag: 'test') do
        d.feed(time, @sample_record)
      end

      filtered_records = d.filtered_records
      assert_equal 1, filtered_records.length
      assert_equal @sample_record, filtered_records[0]
    end
  end

  sub_test_case 'check metrics' do
    test 'metrics emitted properly with labels' do
      labels = %[
        <labels>
          source $.field1
          dummy random_column_value
        </labels>
      ]

      modified_config = @default_config.sub("enable_metrics false", "enable_metrics true" + labels)
      modified_config = modified_config.sub("bucket_size 3", "bucket_size 5")
      remaining_ttl = 200
      @mock_redis.expects(:get).returns(nil)
      @mock_redis.expects(:set).with(instance_of(String), "1", ex: 300).returns("OK")

      # Second record: Redis has the key, increment
      @mock_redis.expects(:get).returns("1")
      @mock_redis.expects(:set).with(instance_of(String), "2", ex: remaining_ttl).returns("OK")

      @mock_redis.expects(:get).returns("2")
      @mock_redis.expects(:set).with(instance_of(String), "3", ex: remaining_ttl).returns("OK")

      @mock_redis.expects(:ttl).with(instance_of(String)).returns(remaining_ttl).times(2)

      d = create_driver(modified_config)
      time = event_time("2024-01-01 00:00:00 UTC")

      d.run(default_tag: 'test') do
        3.times do |i|
          record = @sample_record.merge('count' => i)
          d.feed(time, record)
        end
      end

      assert_equal 3, d.instance.registry.get(:fluentd_dedupe_plugin_input).get(labels: {source: "value1", dummy: 'random_column_value'})
      assert_equal 1, d.instance.registry.get(:fluentd_dedupe_plugin_output).get(labels: {source: "value1", dummy: 'random_column_value'})
      assert_equal 2, d.instance.registry.get(:fluentd_dedupe_count).get(labels: {source: "value1", dummy: 'random_column_value'})

      filtered_records = d.filtered_records
      assert_equal 1, filtered_records.length  # First record should pass through, second and third should be filtered out
    end
  end
end
