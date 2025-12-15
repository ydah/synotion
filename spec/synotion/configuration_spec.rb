RSpec.describe Synotion::Configuration do
  describe '#initialize' do
    it 'sets default values' do
      config = described_class.new

      expect(config.unique_property).to eq('source_file')
      expect(config.update_mode).to eq(Synotion::UpdateMode::UPSERT)
      expect(config.title_from).to eq(:first_heading)
      expect(config.sync_metadata).to be true
    end

    it 'reads API key from environment' do
      ENV['NOTION_API_KEY'] = 'test_key'
      config = described_class.new

      expect(config.notion_api_key).to eq('test_key')

      ENV.delete('NOTION_API_KEY')
    end
  end

  describe '#validate!' do
    let(:config) { described_class.new }

    it 'raises error when api_key is missing' do
      config.notion_api_key = nil

      expect { config.validate! }.to raise_error(Synotion::ConfigurationError, /notion_api_key is required/)
    end

    it 'raises error when both database_id and page_id are missing' do
      config.notion_api_key = 'test_key'
      config.database_id = nil
      config.page_id = nil

      expect { config.validate! }.to raise_error(Synotion::ConfigurationError, /Either database_id or page_id/)
    end

    it 'raises error for invalid update_mode' do
      config.notion_api_key = 'test_key'
      config.database_id = 'db_id'
      config.update_mode = :invalid

      expect { config.validate! }.to raise_error(Synotion::ConfigurationError, /Invalid update_mode/)
    end

    it 'validates successfully with valid configuration' do
      config.notion_api_key = 'test_key'
      config.database_id = 'db_id'

      expect { config.validate! }.not_to raise_error
    end
  end
end
