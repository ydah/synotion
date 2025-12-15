RSpec.describe Synotion::Syncer do
  let(:api_key) { 'test_api_key' }
  let(:database_id) { 'test_db_id' }
  let(:client) { instance_double(Synotion::Client) }

  before do
    allow(Synotion::Client).to receive(:new).and_return(client)
  end

  describe '#initialize' do
    it 'initializes with options' do
      syncer = described_class.new(
        notion_api_key: api_key,
        database_id: database_id
      )

      expect(syncer).to be_a(described_class)
    end

    it 'raises error when configuration is invalid' do
      expect {
        described_class.new(notion_api_key: nil, database_id: database_id)
      }.to raise_error(Synotion::ConfigurationError, /notion_api_key is required/)
    end

    it 'uses global configuration when no options provided' do
      Synotion.configure do |config|
        config.notion_api_key = api_key
        config.database_id = database_id
      end

      expect { described_class.new }.not_to raise_error

      Synotion.reset_configuration!
    end
  end

  describe '#sync' do
    let(:syncer) { described_class.new(notion_api_key: api_key, database_id: database_id) }
    let(:test_file) { 'test_file.md' }
    let(:markdown_content) { "# Test\n\nContent" }

    before do
      allow(File).to receive(:exist?).with(test_file).and_return(true)
      allow(File).to receive(:read).with(test_file).and_return(markdown_content)
    end

    it 'syncs a markdown file' do
      allow(client).to receive(:find_page).and_return(nil)
      allow(client).to receive(:create_page).and_return(double(id: 'new_page_id'))

      result = syncer.sync(test_file)

      expect(result[:action]).to eq('created')
      expect(result[:page_id]).to eq('new_page_id')
    end

    it 'raises error when file does not exist' do
      allow(File).to receive(:exist?).with('nonexistent.md').and_return(false)

      expect {
        syncer.sync('nonexistent.md')
      }.to raise_error(ArgumentError, /File not found/)
    end
  end

  describe '#sync_content' do
    let(:syncer) { described_class.new(notion_api_key: api_key, database_id: database_id) }
    let(:markdown_content) { "# Test Title\n\nContent" }
    let(:identifier) { 'test.md' }

    context 'with database sync' do
      context 'when page does not exist' do
        before do
          allow(client).to receive(:find_page).and_return(nil)
          allow(client).to receive(:create_page).and_return(double(id: 'new_page_id'))
        end

        it 'creates a new page in upsert mode' do
          expect(client).to receive(:create_page).with(
            hash_including(database_id: database_id)
          )

          result = syncer.sync_content(markdown_content, identifier)
          expect(result[:action]).to eq('created')
        end

        it 'creates a new page in create mode' do
          expect(client).to receive(:create_page)

          result = syncer.sync_content(markdown_content, identifier, mode: :create)
          expect(result[:action]).to eq('created')
        end

        it 'raises error in replace mode' do
          expect {
            syncer.sync_content(markdown_content, identifier, mode: :replace)
          }.to raise_error(Synotion::PageNotFoundError)
        end

        it 'raises error in append mode' do
          expect {
            syncer.sync_content(markdown_content, identifier, mode: :append)
          }.to raise_error(Synotion::PageNotFoundError)
        end
      end

      context 'when page exists' do
        let(:existing_page) { double(id: 'existing_page_id') }

        before do
          allow(client).to receive(:find_page).and_return(existing_page)
          allow(client).to receive(:update_page)
        end

        it 'updates page in upsert mode' do
          expect(client).to receive(:update_page).with(
            hash_including(
              page_id: 'existing_page_id',
              mode: Synotion::UpdateMode::REPLACE
            )
          )

          result = syncer.sync_content(markdown_content, identifier)
          expect(result[:action]).to eq('updated')
        end

        it 'skips in create mode' do
          expect(client).not_to receive(:create_page)
          expect(client).not_to receive(:update_page)

          result = syncer.sync_content(markdown_content, identifier, mode: :create)
          expect(result[:action]).to eq('skipped')
        end

        it 'replaces in replace mode' do
          expect(client).to receive(:update_page).with(
            hash_including(mode: Synotion::UpdateMode::REPLACE)
          )

          result = syncer.sync_content(markdown_content, identifier, mode: :replace)
          expect(result[:action]).to eq('updated')
        end

        it 'appends in append mode' do
          expect(client).to receive(:update_page).with(
            hash_including(mode: Synotion::UpdateMode::APPEND)
          )

          result = syncer.sync_content(markdown_content, identifier, mode: :append)
          expect(result[:action]).to eq('appended')
        end
      end
    end

    context 'with page sync' do
      let(:page_id) { 'test_page_id' }
      let(:syncer) { described_class.new(notion_api_key: api_key, page_id: page_id) }

      it 'updates page directly in replace mode' do
        expect(client).to receive(:update_page).with(
          hash_including(
            page_id: page_id,
            mode: Synotion::UpdateMode::REPLACE
          )
        )

        result = syncer.sync_content(markdown_content, identifier, mode: :replace)
        expect(result[:action]).to eq('updated')
      end

      it 'appends to page in append mode' do
        expect(client).to receive(:update_page).with(
          hash_including(
            page_id: page_id,
            mode: Synotion::UpdateMode::APPEND
          )
        )

        result = syncer.sync_content(markdown_content, identifier, mode: :append)
        expect(result[:action]).to eq('appended')
      end

      it 'raises error for invalid mode' do
        expect {
          syncer.sync_content(markdown_content, identifier, mode: :create)
        }.to raise_error(ArgumentError, /Invalid mode for page sync/)
      end
    end

    it 'raises error when neither database_id nor page_id is specified' do
      syncer = described_class.new(notion_api_key: api_key, database_id: 'temp')

      allow(syncer.config).to receive(:database_id).and_return(nil)
      allow(syncer.config).to receive(:page_id).and_return(nil)

      expect {
        syncer.sync_content(markdown_content, identifier)
      }.to raise_error(Synotion::ConfigurationError, /Either page_id or database_id/)
    end

    it 'uses custom title when provided' do
      allow(client).to receive(:find_page).and_return(nil)
      allow(client).to receive(:create_page).and_return(double(id: 'new_page_id'))

      expect(client).to receive(:create_page) do |args|
        expect(args[:properties]['title']['title'][0]['text']['content']).to eq('Custom Title')
        double(id: 'new_page_id')
      end

      syncer.sync_content(markdown_content, identifier, title: 'Custom Title')
    end
  end
end
