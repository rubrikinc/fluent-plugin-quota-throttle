# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/fluent/plugin/parser'
class ParserTest < Minitest::Test
  def setup
    @config_file_path = Dir.pwd+"/test/modules/parser_test.yml"
    @configuration = Parser::Configuration.new(@config_file_path)
  end

  def test_parse_quotas
    refute_nil @configuration.instance_variable_get(:@quotas)
    assert_equal 2, @configuration.instance_variable_get(:@quotas).length
  end

  def test_get_quota
    # Check if the correct quota is retrieved from above definition
    # UT 1: Subset of groups match fully
    keys = { "group1" => "value1" , "group2" => "value2" }
    quota = @configuration.get_quota(keys)
    assert_equal "quota1", quota.name

    # UT 2: All groups match fully
    keys = { "group1" => "value2" , "group2" => "value3" }
    quota = @configuration.get_quota(keys)
    assert_equal "quota2", quota.name

    # UT 3: Subset of group match partially
    keys = { "group1" => "value2" , "group2" => "value2" }
    quota = @configuration.get_quota(keys)
    assert_nil quota

    # UT 4: None of the group matches
    keys = { "group1" => "value3" , "group2" => "value2" }
    quota = @configuration.get_quota(keys)
    assert_nil quota
  end

  def test_matching_score
    # Testing the private helper function
    score = @configuration.send(:matching_score, { "key1" => "value1" , "key2" => "value2" }, { "key1" => "value1" , "key2" => "value2" })
    assert_equal 2, score

    score = @configuration.send(:matching_score, { "key1" => "value1" }, { "key2" => "value2" })
    assert_equal -1, score

    score = @configuration.send(:matching_score, { "key1" => "value1" , "key2" => "value2" }, { "key1" => "value1" , "key2" => "value3" })
    assert_equal -1, score

    score = @configuration.send(:matching_score, nil, { "key1" => "value1" })
    assert_equal 0, score

    score = @configuration.send(:matching_score, { "key1" => "value1" }, nil)
    assert_equal 0, score

    score = @configuration.send(:matching_score, nil, nil)
    assert_equal 0, score
  end
end
