require 'yaml'

module Parser

  Quota = Struct.new(:name, :desc, :group_by, :match_by, :bucket_size, :duration)

  class Configuration

    def initialize(config_file_path)
      @config_file= YAML.load(config_file_path)
      parse_quotas
    end

    def get_quota(keys)
      max_score = -1
      quota_to_return = nil
      @quotas.each do |quota|
        score = matching_score(quota.match_by, keys)
        if score > max_score
          max_score = score
          quota_to_return = quota
        end
      end
      quota_to_return
    end

    private

    def parse_quotas
      @quotas = @config_file["quotas"].map do |quota|
        Quota.new(quota["name"], quota["description"], quota["group_by"], quota["match_by"], quota["bucket_size"], quota["duration"])
      end
    end

    def matching_score(hash1, hash2)
      score = 0
      if hash1.nil? || hash2.nil?
        return 0
      end
      hash1.each do |key, value|
        score += 1 if hash2[key] == value
      end
      if score == 0
        return -1
      end
      score
    end
end
