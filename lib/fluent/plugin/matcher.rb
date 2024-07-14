##
# This module is responsible for matching records to quotas.
module Matcher

  ##
  # MatchHelper class is responsible for matching records to quotas.
  # Methods:
  #   +get_quota+: Takes a list of keys and returns the quota that maximally matches
  #   +matching_score+: Calculates the matching score between two hashes.
  class MatchHelper

    def initialize(processed_quotas,default_quota)
      @quotas = processed_quotas
      @default_quota = default_quota
    end

    # Takes a list of keys and returns the quota that maximally matches
    # If no quota matches, returns the default quota
    # Params:
    #   +record+: (Hash) A hash of keys and values to match against the quotas
    # Returns:
    #   +quota+: (Quota Class)The quota that maximally matches the record
    def get_quota(record)

      max_score = 0
      quota_to_return = @default_quota
      if @quotas.nil?
        return @default_quota
      end
      @quotas.each do |quota|
        score = matching_score(quota.match_by, record)
        if score > max_score
          max_score = score
          quota_to_return = quota
        end
      end
      quota_to_return
    end

    private

    # Calculates the matching score between two hashes.
    # Params:
    #   +match+: (Hash) A hash of keys and values to match against the record
    #   +record+: (Hash) A hash of keys and values to match against the match
    def matching_score(match, record)
      score = 0
      if match.nil? || record.nil?
        return 0
      end
      match.each do |key, value|
        if record.dig(*key) == value
          score += 1
        else
          return 0
        end
      end
      score
    end
  end
end
