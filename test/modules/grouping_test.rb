require 'minitest/autorun'
require_relative '../../lib/fluent/plugin/grouping'
require_relative '../../lib/fluent/plugin/parser'
class TestBucket < Minitest::Test
  def setup
    # Initialize bucket with dummy parameters
    @bucket = Grouping::Bucket.new(0, Time.now, 0, Time.now, 0, nil, 10, 2)
  end

  def test_bucket_initialization
    assert_equal 0, @bucket.bucket_count
    assert @bucket.bucket_last_reset <= Time.now
    assert_equal 0, @bucket.approx_rate
    assert @bucket.rate_last_reset <= Time.now
    assert_equal 0, @bucket.curr_count
    assert_nil @bucket.last_warning
    assert_equal 10, @bucket.instance_variable_get(:@bucket_limit)
    assert_equal 2, @bucket.instance_variable_get(:@bucket_period)
    assert_equal 5, @bucket.instance_variable_get(:@rate_limit)
    assert_equal 4, @bucket.timeout_s
  end

  def test_bucket_increment_free
    @bucket.increment
    assert_equal 1, @bucket.bucket_count
  end

  def test_bucket_increment_full
    11.times { @bucket.increment }
    assert_equal false, @bucket.increment
  end

  def test_reset_bucket
    @bucket.increment
    @bucket.send(:reset_bucket)
    assert_equal 0, @bucket.bucket_count
  end
end

class TestCounters < Minitest::Test
  def setup
    @counters = Grouping::Counters.new
    @quota = ConfigParser::Quota.new("Dummy", "dummy quota for testing",[["group1","a"],["group1","b"]], {["group1","a"] => "value1"}, 10, 2, "reemit")
  end

  def test_get_counter
    group = "value1"
    counter = @counters.get_counter(group, @quota)
    assert_instance_of Grouping::Bucket, counter
    assert_equal 10, counter.instance_variable_get(:@bucket_limit)
    assert_equal 2, counter.instance_variable_get(:@bucket_period)
  end

  def test_clean_counters
    group1 = "value1"
    @counters.get_counter(group1, @quota)
    group2 = "value2"
    @counters.get_counter(group2, @quota)
    lru_group, lru_counter = @counters.instance_variable_get(:@counters).first
    assert_equal group1, lru_group
    @counters.clean_counters
    lru_group, lru_counter = @counters.instance_variable_get(:@counters).first
    assert_equal group2, lru_group
  end
end