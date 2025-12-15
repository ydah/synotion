require 'thor'
require 'yaml'

module Synotion
  class CLI < Thor
    desc 'sync FILE_PATH', 'Sync a markdown file to Notion'
    method_option :api_key, type: :string, desc: 'Notion API key (or set NOTION_API_KEY env var)'
    method_option :database_id, type: :string, desc: 'Notion database ID'
    method_option :page_id, type: :string, desc: 'Notion page ID for direct update'
    method_option :mode, type: :string, default: 'upsert', desc: 'Update mode: create, append, replace, upsert'
    method_option :unique_property, type: :string, default: 'source_file', desc: 'Property name for unique identification'
    method_option :unique_value, type: :string, desc: 'Value for unique property (defaults to file path)'
    method_option :title, type: :string, desc: 'Custom page title'
    method_option :config, type: :string, desc: 'Path to config file (.notion-sync.yml)'

    def sync(file_path)
      if options[:config] && File.exist?(options[:config])
        load_config_file(options[:config])
      end

      syncer_options = {}
      syncer_options[:notion_api_key] = options[:api_key] if options[:api_key]
      syncer_options[:database_id] = options[:database_id] if options[:database_id]
      syncer_options[:page_id] = options[:page_id] if options[:page_id]

      sync_options = {}
      sync_options[:mode] = options[:mode].to_sym if options[:mode]
      sync_options[:unique_property] = options[:unique_property] if options[:unique_property]
      sync_options[:unique_value] = options[:unique_value] if options[:unique_value]
      sync_options[:title] = options[:title] if options[:title]

      syncer = Syncer.new(syncer_options)
      result = syncer.sync(file_path, sync_options)

      puts "✓ Successfully #{result[:action]} page"
      puts "  Page ID: #{result[:page_id]}"
      puts "  Mode: #{result[:mode]}" if result[:mode]
    rescue StandardError => e
      puts "✗ Error: #{e.message}"
      exit 1
    end

    desc 'version', 'Show version'
    def version
      puts "Synotion version #{Synotion::VERSION}"
    end

    private

    def load_config_file(config_path)
      config_data = YAML.load_file(config_path)

      Synotion.configure do |config|
        config.notion_api_key = config_data['notion_api_key'] if config_data['notion_api_key']
        config.database_id = config_data['database_id'] if config_data['database_id']
        config.page_id = config_data['page_id'] if config_data['page_id']
        config.unique_property = config_data['unique_property'] if config_data['unique_property']
        config.update_mode = config_data['update_mode'].to_sym if config_data['update_mode']
        config.title_from = config_data['title_from'].to_sym if config_data['title_from']
        config.sync_metadata = config_data['sync_metadata'] if config_data.key?('sync_metadata')
      end
    rescue StandardError => e
      puts "Warning: Failed to load config file: #{e.message}"
    end
  end
end
