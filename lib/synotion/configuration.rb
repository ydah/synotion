module Synotion
  class Configuration
    attr_accessor :notion_api_key,
                  :database_id,
                  :page_id,
                  :unique_property,
                  :update_mode,
                  :title_from,
                  :sync_metadata

    def initialize
      @notion_api_key = ENV.fetch('NOTION_API_KEY', nil)
      @database_id = nil
      @page_id = nil
      @unique_property = 'source_file'
      @update_mode = UpdateMode::UPSERT
      @title_from = :first_heading
      @sync_metadata = true
    end

    def validate!
      raise ConfigurationError, 'notion_api_key is required' if notion_api_key.nil? || notion_api_key.empty?
      raise ConfigurationError, 'Either database_id or page_id must be specified' if database_id.nil? && page_id.nil?
      raise ConfigurationError, "Invalid update_mode: #{update_mode}" unless UpdateMode.valid?(update_mode)
    end
  end
end
