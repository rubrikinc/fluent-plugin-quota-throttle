require 'yaml'

##
# ConfigParser module contains classes to parse the configuration file and store the quotas
module ConfigParser

  ##
  # Quota class represents a single quota configuration
  # Attributes:
  #   +name+: (String) The name of the quota.
  #   +desc+: (String) A description of the quota.
  #   +group_by+: (Array of Arrays of Strings) Specifies how to group transactions or events for quota tracking.
  #   +match_by+: (Hash) Defines the conditions that must be met for the quota to apply. Keys are the conditions to match, and values are the expected values.
  #   +bucket_size+: (Integer) The size of the quota bucket, indicating how many transactions or events can occur before the quota is exceeded. A value of -1 indicates no quota limit.
  #   +duration+: (Integer) The duration (in seconds) for which the quota bucket size is valid.
  #   +action+: (String) The action to take when the quota is reached. Must be one of the predefined actions in @@allowed_actions.
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

  ##
  # Configuration class parses the configuration file and stores the quotas
  # Attributes:
  #   +quotas+: (Array of Quota) The list of quotas parsed from the configuration file.
  #   +default_quota+: (Quota) The default quota to use when no other quota matches.
  class Configuration

    attr_reader :quotas,:default_quota

    def initialize(config_file_path)
      @config_file= YAML.load_file(config_file_path)
      @quotas = nil
      @default_quota = nil
      parse_quotas
    end

    private

    # Parses the quotas from the configuration file into Quota objects and stores them in @quotas
    def parse_quotas
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
        @default_quota = Quota.new("default", "Default quota", [], [], -1, 0, "drop")
      end
    end
  end
end
