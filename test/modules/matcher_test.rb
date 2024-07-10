require 'minitest/autorun'
require_relative '../../lib/fluent/plugin/parser'
require_relative '../../lib/fluent/plugin/matcher'

class MatcherTest < Minitest::Test
  def setup
    config_file_path = Dir.pwd+"/test/config_files/matcher_test.yml"
    config_parser = ConfigParser::Configuration.new(config_file_path)
    quotas = config_parser.quotas
    @default_quota = config_parser.default_quota
    @match_helper = Matcher::MatchHelper.new(quotas,@default_quota)
  end

  def test_get_quota
    # Check if the correct quota is retrieved from above definition
    # UT 1: Subset of groups match fully
    keys = { "group1" => { "a" => "value1" , "b" => "value2" } }
    quota = @match_helper.get_quota(keys)
    assert_equal "quota1", quota.name

    # UT 2: All groups match fully
    keys = { "group1" => {"a" => "value2" , "b" => "value3" } }
    quota = @match_helper.get_quota(keys)
    assert_equal "quota2", quota.name

    # UT 3: Subset of group match partially
    keys = { "group1" => { "a" => "value2" , "b" => "value2" } }
    quota = @match_helper.get_quota(keys)
    assert_equal @default_quota, quota

    # UT 4: None of the group matches
    keys = { "group1" => { "a" => "value3" , "b" => "value2" } }
    quota = @match_helper.get_quota(keys)
    assert_equal @default_quota, quota

    # UT 5: Non-nested group matches
    keys = { "group2" => "value2" , "group3" => "value3" }
    quota = @match_helper.get_quota(keys)
    assert_equal "quota3", quota.name

    # UT 6: Non-nested group mismatches
    keys = { "group2" => "value2" , "group3" => "value4" }
    quota = @match_helper.get_quota(keys)
    assert_equal @default_quota, quota
  end

  def test_matching_score
    # Testing the private helper function
    score = @match_helper.send(:matching_score, { "key1" => "value1" , "key2" => "value2" }, { "key1" => "value1" , "key2" => "value2" })
    assert_equal 2, score

    score = @match_helper.send(:matching_score, { "key1" => "value1" }, { "key2" => "value2" })
    assert_equal 0, score

    score = @match_helper.send(:matching_score, { "key1" => "value1" , "key2" => "value2" }, { "key1" => "value1" , "key2" => "value3" })
    assert_equal 0, score

    score = @match_helper.send(:matching_score, nil, { "key1" => "value1" })
    assert_equal 0, score

    score = @match_helper.send(:matching_score, { "key1" => "value1" }, nil)
    assert_equal 0, score

    score = @match_helper.send(:matching_score, nil, nil)
    assert_equal 0, score
  end


end