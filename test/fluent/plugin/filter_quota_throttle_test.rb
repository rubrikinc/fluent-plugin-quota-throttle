require_relative '../../helper'

class QuotaThrottleFilterTest < Minitest::Test
  include Fluent::Test::Helpers

  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    path test/config_files/matcher_test.yml
    warning_delay 30
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::QuotaThrottleFilter).configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal "test/config_files/matcher_test.yml", d.instance.path
    assert_equal 30, d.instance.warning_delay
  end

  def test_filter
    d = create_driver
    d.run(default_tag: 'test') do
      d.feed("group1" => { "a" => "value1" , "b" => "value2" })
      d.feed("group1" => { "a" => "value2" , "b" => "value3" })
      d.feed("group1" => { "a" => "value2" , "b" => "value2" })
      d.feed("group1" => { "a" => "value3" , "b" => "value2" })
      d.feed("group2" => "value2" , "group3" => "value3")
      d.feed("group2" => "value2" , "group3" => "value4")
    end
    events = d.filtered_records
    assert_equal 6, events.length
    assert_equal({"group1" => { "a" => "value1" , "b" => "value2" }}, events[0])
    assert_equal({"group1" => { "a" => "value2" , "b" => "value3" }}, events[1])
    assert_equal({"group1" => { "a" => "value2" , "b" => "value2" }}, events[2])
    assert_equal({"group1" => { "a" => "value3" , "b" => "value2" }}, events[3])
    assert_equal({"group2" => "value2" , "group3" => "value3"}, events[4])
    assert_equal({"group2" => "value2" , "group3" => "value4"}, events[5])
  end
end