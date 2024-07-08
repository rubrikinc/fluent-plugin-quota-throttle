# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/fluent/plugin/parser'
class ParserTest < Minitest::Test
  def setup
    @config_file_path = Dir.pwd+"/test/modules/parser_test.yml"
    @quotas = ConfigParser::Configuration.new(@config_file_path).quotas
  end

  def test_parse_quotas
    # Check if the quotas are parsed correctly
    # TODO 1: Add wrong configuration files and check if it raises errors
    refute_nil @quotas
    assert_equal 2, @quotas.length

    # Check if the quotas are parsed correctly
    assert_equal "quota1", @quotas[0].name
    assert_equal "quota2", @quotas[1].name
    assert_equal "first quota", @quotas[0].desc
    assert_equal "second quota", @quotas[1].desc
    assert_equal [["group1", "a"]], @quotas[0].group_by
    assert_equal [["group1", "a"], ["group1", "b"]], @quotas[1].group_by
    assert_equal 100, @quotas[0].bucket_size
    assert_equal 200, @quotas[1].bucket_size
    assert_equal 60, @quotas[0].duration
    assert_equal 120, @quotas[1].duration
    assert_equal "delete", @quotas[0].action
    assert_equal "reemit", @quotas[1].action
    assert_equal ({["group1", "a"] => "value1"}), @quotas[0].match_by
    assert_equal ({["group1", "a"] => "value2", ["group1", "b"] => "value3"}), @quotas[1].match_by
  end

end
