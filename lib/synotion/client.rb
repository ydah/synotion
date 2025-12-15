require 'notion-ruby-client'

module Synotion
  class Client
    attr_reader :api_client

    def initialize(api_key)
      @api_client = Notion::Client.new(token: api_key)
    end

    def find_page(database_id:, property:, value:)
      response = api_client.database_query(
        database_id: database_id,
        filter: {
          property: property,
          rich_text: {
            equals: value
          }
        }
      )

      return nil if response.results.empty?

      response.results.first
    rescue Notion::Api::Errors::NotionError => e
      raise NotionAPIError, "Failed to find page: #{e.message}"
    end

    def create_page(database_id:, properties:, children: [])
      response = api_client.create_page(
        parent: { database_id: database_id },
        properties: properties,
        children: children
      )
      response
    rescue Notion::Api::Errors::NotionError => e
      raise NotionAPIError, "Failed to create page: #{e.message}"
    end

    def update_page(page_id:, children:, mode:)
      case mode
      when UpdateMode::REPLACE
        delete_blocks(page_id)
        append_blocks(page_id, children)
      when UpdateMode::APPEND
        append_blocks(page_id, children)
      else
        raise ArgumentError, "Invalid update mode for update_page: #{mode}"
      end
    rescue Notion::Api::Errors::NotionError => e
      raise NotionAPIError, "Failed to update page: #{e.message}"
    end

    def append_blocks(page_id, children)
      return if children.empty?

      children.each_slice(100) do |chunk|
        api_client.block_append_children(
          block_id: page_id,
          children: chunk
        )
      end
    rescue Notion::Api::Errors::NotionError => e
      raise NotionAPIError, "Failed to append blocks: #{e.message}"
    end

    def delete_blocks(page_id)
      blocks = get_page_blocks(page_id)
      blocks.each do |block|
        api_client.delete_block(block_id: block.id)
      end
    rescue Notion::Api::Errors::NotionError => e
      raise NotionAPIError, "Failed to delete blocks: #{e.message}"
    end

    def get_page_blocks(page_id)
      blocks = []
      cursor = nil

      loop do
        response = api_client.block_children(
          block_id: page_id,
          start_cursor: cursor
        )

        blocks.concat(response.results)

        break unless response.has_more
        cursor = response.next_cursor
      end

      blocks
    rescue Notion::Api::Errors::NotionError => e
      raise NotionAPIError, "Failed to get page blocks: #{e.message}"
    end

    def update_page_properties(page_id:, properties:)
      api_client.update_page(
        page_id: page_id,
        properties: properties
      )
    rescue Notion::Api::Errors::NotionError => e
      raise NotionAPIError, "Failed to update page properties: #{e.message}"
    end
  end
end
