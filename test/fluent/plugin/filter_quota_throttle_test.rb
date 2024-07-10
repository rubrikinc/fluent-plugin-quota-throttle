require_relative '../../helper'

class QuotaThrottleFilterTest < Minitest::Test
  include Fluent::Test::Helpers

  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    path test/config_files/filter_plugin_test.yml
    warning_delay 30
  ]

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::QuotaThrottleFilter).configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal "test/config_files/filter_plugin_test.yml", d.instance.path
    assert_equal 30, d.instance.warning_delay
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
end