require 'minitest/autorun'
require_relative '../../lib/fluent/plugin/parser'
require_relative '../../lib/fluent/plugin/matcher'

class ParserTest < Minitest::Test
  def setup
    @config_file_path = Dir.pwd+"/test/config_files/matcher_test.yml"
    @quotas = ConfigParser::Configuration.new(@config_file_path).quotas
    @quota_info = Matcher::Match_Helper.new(@quotas)
  end

  def test_get_quota
    # Check if the correct quota is retrieved from above definition
    # UT 1: Subset of groups match fully
    keys = { "group1" => { "a" => "value1" , "b" => "value2" } }
    quota = @quota_info.get_quota(keys)
    assert_equal "quota1", quota.name

    # UT 2: All groups match fully
    keys = { "group1" => {"a" => "value2" , "b" => "value3" } }
    quota = @quota_info.get_quota(keys)
    assert_equal "quota2", quota.name

    # UT 3: Subset of group match partially
    keys = { "group1" => { "a" => "value2" , "b" => "value2" } }
    quota = @quota_info.get_quota(keys)
    assert_nil quota

    # UT 4: None of the group matches
    keys = { "group1" => { "a" => "value3" , "b" => "value2" } }
    quota = @quota_info.get_quota(keys)
    assert_nil quota
  end

  def test_matching_score
    # Testing the private helper function
    score = @quota_info.send(:matching_score, { "key1" => "value1" , "key2" => "value2" }, { "key1" => "value1" , "key2" => "value2" })
    assert_equal 2, score

    score = @quota_info.send(:matching_score, { "key1" => "value1" }, { "key2" => "value2" })
    assert_equal -1, score

    score = @quota_info.send(:matching_score, { "key1" => "value1" , "key2" => "value2" }, { "key1" => "value1" , "key2" => "value3" })
    assert_equal -1, score

    score = @quota_info.send(:matching_score, nil, { "key1" => "value1" })
    assert_equal 0, score

    score = @quota_info.send(:matching_score, { "key1" => "value1" }, nil)
    assert_equal 0, score

    score = @quota_info.send(:matching_score, nil, nil)
    assert_equal 0, score
  end


end