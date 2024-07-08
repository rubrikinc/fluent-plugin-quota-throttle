require 'yaml'

module ConfigParser

  class Quota

    attr_accessor :name, :desc, :group_by, :match_by, :bucket_size, :duration, :action

    @@allowed_actions = Set["drop", "reemit"]

    def initialize(name, desc, group_by, match_by, bucket_size, duration, action)
      raise "Name cannot be empty" if name.nil?
      raise "Group by cannot be empty" if group_by.nil?
      raise "Bucket size cannot be empty" unless bucket_size.is_a?(Integer)
      raise "Duration cannot be empty" unless duration.is_a?(Integer)
      raise "Action must be one of #{@@allowed_actions}" unless @@allowed_actions.include?action
      @name = name
      @desc = desc
      @group_by = group_by
      @match_by = match_by
      @bucket_size = bucket_size
      @duration = duration
      @action = action
    end
  end

  class Configuration

    attr_reader :quotas,:default_quota

    def initialize(config_file_path)
      @config_file= YAML.load_file(config_file_path)
      @quotas = nil
      parse_quotas
    end

    private

    def parse_quotas
      # Parses the quotas from the configuration file into Quota objects and stores them in @quotas
      if @config_file.has_key?("quotas")
        @quotas = @config_file["quotas"].map do |quota|
          group_key = quota["group_by"].map { |key| key.split(".") }
          match_by = quota["match_by"].map { |key,value| [key.split(".") , value] }.to_h
          Quota.new(quota["name"], quota["description"], group_key, match_by, quota["bucket_size"], quota["duration"], quota["action"])
        end
      end
      if @config_file.has_key?("default")
        default_quota_config = @config_file["default"]
        @default_quota = Quota.new("default", default_quota_config["description"], default_quota_config["group_by"].map { |key| key.split(".") }, [], default_quota_config["bucket_size"], default_quota_config["duration"], default_quota_config["action"])
      else
        raise "Default quota not found in configuration file"
      end
    end
  end
end
