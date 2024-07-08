module Matcher

  class Match_Helper

    def initialize(processed_quotas)
      @quotas = processed_quotas
    end

    def get_quota(record)
      # Takes a list of keys and returns the quota that maximally matches
      max_score = -1
      quota_to_return = nil
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
      # 0 is used to determine the match with default quota
      # -1 i used to determine a mismatch with match_by clauses
      score = 0
      if match.nil? || record.nil?
        return 0
      end
      match.each do |key, value|
        if record.dig(*key) == value
          score += 1
        else
          return -1
        end
      end
      if score == 0
        return -1
      end
      score
    end
  end
end
