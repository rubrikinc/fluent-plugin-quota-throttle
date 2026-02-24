# frozen_string_literal: true
require_relative '../helper'

class ParserTest < Minitest::Test
  def setup
    config_file_path = Dir.pwd+"/test/config_files/parser_test.yml"
    config_parser = ConfigParser::Configuration.new(config_file_path)
    @quotas = config_parser.quotas
    @default_quota = config_parser.default_quota
  end

  def test_parse_quotas
    # Check if the quotas are parsed correctly
    # TODO 1: Add wrong configuration files and check if it raises errors
    refute_nil @quotas
    assert_equal 3, @quotas.length

    # Check if the quotas are parsed correctly
    assert_equal "quota1", @quotas[0].name
    assert_equal "quota2", @quotas[1].name
    assert_equal "quota3", @quotas[2].name
    assert_equal "first quota", @quotas[0].desc
    assert_equal "second quota", @quotas[1].desc
    assert_equal "third quota with fallback", @quotas[2].desc
    assert_equal [["group1", "a"]], @quotas[0].group_by
    assert_equal [["group1", "a"], ["group1", "b"]], @quotas[1].group_by
    assert_equal [["group1", "a"]], @quotas[2].group_by
    assert_equal 100, @quotas[0].bucket_size
    assert_equal 200, @quotas[1].bucket_size
    assert_equal 500, @quotas[2].bucket_size
    assert_equal 60, @quotas[0].duration
    assert_equal 120, @quotas[1].duration
    assert_equal 600, @quotas[2].duration
    assert_equal "drop", @quotas[0].action
    assert_equal "reemit", @quotas[1].action
    assert_equal "fallback", @quotas[2].action
    assert_equal ({["group1", "a"] => "value1"}), @quotas[0].match_by
    assert_equal ({["group1", "a"] => "value2", ["group1", "b"] => "value3"}), @quotas[1].match_by
    assert_equal ({["group1", "a"] => "value3"}), @quotas[2].match_by
    assert_equal "default", @default_quota.name
    assert_equal "default quota", @default_quota.desc
    assert_equal [["group1", "a"]], @default_quota.group_by
    assert_equal [], @default_quota.match_by
    assert_equal 300, @default_quota.bucket_size
    assert_equal 180, @default_quota.duration
    assert_equal "reemit", @default_quota.action
  end

  def test_fallback_quota
    # Test fallback quota functionality
    fallback_quota = @quotas[2]

    # Check that fallback quota exists
    refute_nil fallback_quota.fallback_quota

    # Check fallback quota properties
    assert_equal "quota3_#{ConfigParser::Quota::FALLBACK_SUFFIX}", fallback_quota.fallback_quota.name
    assert_equal "Fallback for third quota with fallback", fallback_quota.fallback_quota.desc
    assert_equal [["group1", "a"]], fallback_quota.fallback_quota.group_by
    assert_equal ({["group1", "a"] => "value3"}), fallback_quota.fallback_quota.match_by
    assert_equal 25, fallback_quota.fallback_quota.bucket_size
    assert_equal 60, fallback_quota.fallback_quota.duration
    assert_equal "drop", fallback_quota.fallback_quota.action

    # Check that fallback quota doesn't have its own fallback
    assert_nil fallback_quota.fallback_quota.fallback_quota
  end

  def test_non_fallback_quotas_have_no_fallback
    # Test that non-fallback quotas don't have fallback_quota
    assert_nil @quotas[0].fallback_quota
    assert_nil @quotas[1].fallback_quota
    assert_nil @default_quota.fallback_quota
  end

end
