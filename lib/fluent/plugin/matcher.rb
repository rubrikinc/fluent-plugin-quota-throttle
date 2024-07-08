module Matcher

  class MatchHelper

    def initialize(processed_quotas,default_quota)
      @quotas = processed_quotas
      @default_quota = default_quota
    end

    def get_quota(record)
      # Takes a list of keys and returns the quota that maximally matches
      max_score = 0
      quota_to_return = @default_quota
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

    def matching_score(match, record)
      # Calculates the matching score between two hashes.
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
