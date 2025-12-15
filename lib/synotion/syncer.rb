require 'time'

module Synotion
  class Syncer
    attr_reader :config, :client

    def initialize(options = {})
      @config = build_config(options)
      @config.validate!
      @client = Client.new(@config.notion_api_key)
    end

    def sync(markdown_file_path, options = {})
      raise ArgumentError, "File not found: #{markdown_file_path}" unless File.exist?(markdown_file_path)

      markdown_content = File.read(markdown_file_path)
      identifier = options[:unique_value] || markdown_file_path

      sync_content(markdown_content, identifier, options.merge(filename: markdown_file_path))
    end

    def sync_content(markdown_content, identifier, options = {})
      mode = options[:mode] || config.update_mode
      database_id = options[:database_id] || config.database_id
      page_id = options[:page_id] || config.page_id

      converter = MarkdownConverter.new(markdown_content)
      blocks = converter.to_notion_blocks
      title = options[:title] || extract_title(converter, options[:filename])

      if page_id
        sync_to_page(page_id, blocks, mode, title)
      elsif database_id
        unique_property = options[:unique_property] || config.unique_property
        sync_to_database(database_id, identifier, blocks, mode, title, unique_property, options)
      else
        raise ConfigurationError, 'Either page_id or database_id must be specified'
      end
    end

    private

    def build_config(options)
      if options.empty?
        Synotion.configuration
      else
        config = Configuration.new
        options.each do |key, value|
          config.public_send("#{key}=", value) if config.respond_to?("#{key}=")
        end
        config
      end
    end

    def extract_title(converter, filename = nil)
      case config.title_from
      when :first_heading
        converter.extract_title || (filename ? File.basename(filename, '.*') : 'Untitled')
      when :filename
        filename ? File.basename(filename, '.*') : 'Untitled'
      when :custom
        'Untitled'
      else
        converter.extract_title || 'Untitled'
      end
    end

    def sync_to_page(page_id, blocks, mode, title)
      case mode
      when UpdateMode::REPLACE
        client.update_page(page_id: page_id, children: blocks, mode: mode)
        { action: 'updated', page_id: page_id, mode: mode }
      when UpdateMode::APPEND
        client.update_page(page_id: page_id, children: blocks, mode: mode)
        { action: 'appended', page_id: page_id, mode: mode }
      else
        raise ArgumentError, "Invalid mode for page sync: #{mode}. Use :replace or :append"
      end
    end

    def sync_to_database(database_id, identifier, blocks, mode, title, unique_property, options)
      existing_page = client.find_page(
        database_id: database_id,
        property: unique_property,
        value: identifier
      )

      case mode
      when UpdateMode::CREATE
        if existing_page
          { action: 'skipped', page_id: existing_page.id, reason: 'page already exists' }
        else
          create_database_page(database_id, identifier, blocks, title, unique_property, options)
        end
      when UpdateMode::UPSERT
        if existing_page
          update_database_page(existing_page.id, blocks, UpdateMode::REPLACE)
        else
          create_database_page(database_id, identifier, blocks, title, unique_property, options)
        end
      when UpdateMode::REPLACE
        if existing_page
          update_database_page(existing_page.id, blocks, UpdateMode::REPLACE)
        else
          raise PageNotFoundError, "Page not found for identifier: #{identifier}"
        end
      when UpdateMode::APPEND
        if existing_page
          update_database_page(existing_page.id, blocks, UpdateMode::APPEND)
        else
          raise PageNotFoundError, "Page not found for identifier: #{identifier}"
        end
      else
        raise ArgumentError, "Invalid update mode: #{mode}"
      end
    end

    def create_database_page(database_id, identifier, blocks, title, unique_property, options)
      properties = build_properties(title, identifier, unique_property, options[:additional_properties])

      response = client.create_page(
        database_id: database_id,
        properties: properties,
        children: blocks
      )

      { action: 'created', page_id: response.id, mode: UpdateMode::CREATE }
    end

    def update_database_page(page_id, blocks, mode)
      client.update_page(page_id: page_id, children: blocks, mode: mode)

      action = mode == UpdateMode::REPLACE ? 'updated' : 'appended'
      { action: action, page_id: page_id, mode: mode }
    end

    def build_properties(title, identifier, unique_property, additional_properties = {})
      properties = {
        'title' => {
          'title' => [
            {
              'text' => {
                'content' => title
              }
            }
          ]
        }
      }

      if unique_property != 'title'
        properties[unique_property] = {
          'rich_text' => [
            {
              'text' => {
                'content' => identifier
              }
            }
          ]
        }
      end

      if config.sync_metadata
        properties['last_synced'] = {
          'date' => {
            'start' => Time.now.iso8601
          }
        }
      end

      properties.merge!(additional_properties) if additional_properties

      properties
    end
  end
end
