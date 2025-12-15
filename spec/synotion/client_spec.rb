RSpec.describe Synotion::Client do
  let(:api_key) { 'test_api_key' }
  let(:client) { described_class.new(api_key) }
  let(:api_client) { instance_double(Notion::Client) }

  before do
    allow(Notion::Client).to receive(:new).with(token: api_key).and_return(api_client)
  end

  describe '#initialize' do
    it 'creates a Notion client with the API key' do
      expect(Notion::Client).to receive(:new).with(token: api_key)
      described_class.new(api_key)
    end
  end

  describe '#find_page' do
    let(:database_id) { 'test_db_id' }
    let(:property) { 'source_file' }
    let(:value) { 'README.md' }
    let(:response) { double('response', results: [double('page', id: 'page_id')]) }

    it 'queries the database with the correct filter' do
      expect(api_client).to receive(:database_query).with(
        database_id: database_id,
        filter: {
          property: property,
          rich_text: {
            equals: value
          }
        }
      ).and_return(response)

      result = client.find_page(database_id: database_id, property: property, value: value)
      expect(result).to eq(response.results.first)
    end

    it 'returns nil when no results found' do
      empty_response = double('response', results: [])
      allow(api_client).to receive(:database_query).and_return(empty_response)

      result = client.find_page(database_id: database_id, property: property, value: value)
      expect(result).to be_nil
    end

    it 'raises NotionAPIError on API error' do
      error = Notion::Api::Errors::NotionError.new('error', 'API error')
      allow(api_client).to receive(:database_query).and_raise(error)

      expect {
        client.find_page(database_id: database_id, property: property, value: value)
      }.to raise_error(Synotion::NotionAPIError, /Failed to find page/)
    end
  end

  describe '#create_page' do
    let(:database_id) { 'test_db_id' }
    let(:properties) { { 'title' => { 'title' => [{ 'text' => { 'content' => 'Test' } }] } } }
    let(:children) { [{ type: 'paragraph', paragraph: { rich_text: [] } }] }
    let(:response) { double('response', id: 'new_page_id') }

    it 'creates a page in the database' do
      expect(api_client).to receive(:create_page).with(
        parent: { database_id: database_id },
        properties: properties,
        children: children
      ).and_return(response)

      result = client.create_page(database_id: database_id, properties: properties, children: children)
      expect(result).to eq(response)
    end

    it 'raises NotionAPIError on API error' do
      error = Notion::Api::Errors::NotionError.new('error', 'API error')
      allow(api_client).to receive(:create_page).and_raise(error)

      expect {
        client.create_page(database_id: database_id, properties: properties, children: children)
      }.to raise_error(Synotion::NotionAPIError, /Failed to create page/)
    end
  end

  describe '#update_page' do
    let(:page_id) { 'test_page_id' }
    let(:children) { [{ type: 'paragraph', paragraph: { rich_text: [] } }] }

    context 'with replace mode' do
      it 'deletes blocks and appends new ones' do
        expect(client).to receive(:delete_blocks).with(page_id)
        expect(client).to receive(:append_blocks).with(page_id, children)

        client.update_page(page_id: page_id, children: children, mode: Synotion::UpdateMode::REPLACE)
      end
    end

    context 'with append mode' do
      it 'appends blocks without deleting' do
        expect(client).not_to receive(:delete_blocks)
        expect(client).to receive(:append_blocks).with(page_id, children)

        client.update_page(page_id: page_id, children: children, mode: Synotion::UpdateMode::APPEND)
      end
    end

    it 'raises error for invalid mode' do
      expect {
        client.update_page(page_id: page_id, children: children, mode: :invalid)
      }.to raise_error(ArgumentError, /Invalid update mode/)
    end
  end

  describe '#append_blocks' do
    let(:page_id) { 'test_page_id' }
    let(:children) { [{ type: 'paragraph', paragraph: { rich_text: [] } }] }

    it 'appends blocks to the page' do
      expect(api_client).to receive(:block_append_children).with(
        block_id: page_id,
        children: children
      )

      client.append_blocks(page_id, children)
    end

    it 'handles empty children array' do
      expect(api_client).not_to receive(:block_append_children)
      client.append_blocks(page_id, [])
    end

    it 'handles more than 100 blocks by chunking' do
      large_children = Array.new(150) { { type: 'paragraph', paragraph: { rich_text: [] } } }

      expect(api_client).to receive(:block_append_children).twice

      client.append_blocks(page_id, large_children)
    end

    it 'raises NotionAPIError on API error' do
      error = Notion::Api::Errors::NotionError.new('error', 'API error')
      allow(api_client).to receive(:block_append_children).and_raise(error)

      expect {
        client.append_blocks(page_id, children)
      }.to raise_error(Synotion::NotionAPIError, /Failed to append blocks/)
    end
  end

  describe '#delete_blocks' do
    let(:page_id) { 'test_page_id' }
    let(:blocks) { [double('block', id: 'block1'), double('block', id: 'block2')] }

    it 'deletes all blocks from the page' do
      allow(client).to receive(:get_page_blocks).with(page_id).and_return(blocks)

      expect(api_client).to receive(:delete_block).with(block_id: 'block1')
      expect(api_client).to receive(:delete_block).with(block_id: 'block2')

      client.delete_blocks(page_id)
    end

    it 'raises NotionAPIError on API error' do
      error = Notion::Api::Errors::NotionError.new('error', 'API error')
      allow(client).to receive(:get_page_blocks).and_raise(error)

      expect {
        client.delete_blocks(page_id)
      }.to raise_error(Synotion::NotionAPIError, /Failed to delete blocks/)
    end
  end

  describe '#get_page_blocks' do
    let(:page_id) { 'test_page_id' }

    it 'retrieves all blocks from the page' do
      response = double('response', results: [double('block')], has_more: false)
      expect(api_client).to receive(:block_children).with(
        block_id: page_id,
        start_cursor: nil
      ).and_return(response)

      result = client.get_page_blocks(page_id)
      expect(result).to eq(response.results)
    end

    it 'handles pagination' do
      response1 = double('response', results: [double('block1')], has_more: true, next_cursor: 'cursor1')
      response2 = double('response', results: [double('block2')], has_more: false)

      expect(api_client).to receive(:block_children).with(
        block_id: page_id,
        start_cursor: nil
      ).and_return(response1)

      expect(api_client).to receive(:block_children).with(
        block_id: page_id,
        start_cursor: 'cursor1'
      ).and_return(response2)

      result = client.get_page_blocks(page_id)
      expect(result.length).to eq(2)
    end

    it 'raises NotionAPIError on API error' do
      error = Notion::Api::Errors::NotionError.new('error', 'API error')
      allow(api_client).to receive(:block_children).and_raise(error)

      expect {
        client.get_page_blocks(page_id)
      }.to raise_error(Synotion::NotionAPIError, /Failed to get page blocks/)
    end
  end

  describe '#update_page_properties' do
    let(:page_id) { 'test_page_id' }
    let(:properties) { { 'title' => { 'title' => [{ 'text' => { 'content' => 'Updated' } }] } } }

    it 'updates page properties' do
      expect(api_client).to receive(:update_page).with(
        page_id: page_id,
        properties: properties
      )

      client.update_page_properties(page_id: page_id, properties: properties)
    end

    it 'raises NotionAPIError on API error' do
      error = Notion::Api::Errors::NotionError.new('error', 'API error')
      allow(api_client).to receive(:update_page).and_raise(error)

      expect {
        client.update_page_properties(page_id: page_id, properties: properties)
      }.to raise_error(Synotion::NotionAPIError, /Failed to update page properties/)
    end
  end
end
