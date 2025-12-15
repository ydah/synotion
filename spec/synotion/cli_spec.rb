RSpec.describe Synotion::CLI do
  let(:cli) { described_class.new }

  describe '#sync' do
    let(:file_path) { 'test.md' }
    let(:api_key) { 'test_api_key' }
    let(:database_id) { 'test_db_id' }

    before do
      allow(File).to receive(:exist?).with(file_path).and_return(true)
      allow(File).to receive(:read).with(file_path).and_return("# Test\n\nContent")
    end

    it 'syncs a file with basic options' do
      syncer = instance_double(Synotion::Syncer)
      allow(Synotion::Syncer).to receive(:new).and_return(syncer)
      allow(syncer).to receive(:sync).and_return({ action: 'created', page_id: 'test_id', mode: :upsert })

      expect {
        cli.invoke(:sync, [file_path], {
          api_key: api_key,
          database_id: database_id
        })
      }.to output(/Successfully created page/).to_stdout
    end

    it 'syncs a file with custom mode' do
      syncer = instance_double(Synotion::Syncer)
      allow(Synotion::Syncer).to receive(:new).and_return(syncer)
      allow(syncer).to receive(:sync).with(
        file_path,
        hash_including(mode: :append)
      ).and_return({ action: 'appended', page_id: 'test_id', mode: :append })

      expect {
        cli.invoke(:sync, [file_path], {
          api_key: api_key,
          database_id: database_id,
          mode: 'append'
        })
      }.to output(/Successfully appended page/).to_stdout
    end

    it 'handles errors gracefully' do
      syncer = instance_double(Synotion::Syncer)
      allow(Synotion::Syncer).to receive(:new).and_return(syncer)
      allow(syncer).to receive(:sync).and_raise(Synotion::Error, 'Test error')

      expect {
        expect {
          cli.invoke(:sync, [file_path], {
            api_key: api_key,
            database_id: database_id
          })
        }.to raise_error(SystemExit)
      }.to output(/Error: Test error/).to_stdout
    end

    it 'passes unique_value option' do
      syncer = instance_double(Synotion::Syncer)
      allow(Synotion::Syncer).to receive(:new).and_return(syncer)

      expect(syncer).to receive(:sync).with(
        file_path,
        hash_including(unique_value: 'custom_value')
      ).and_return({ action: 'created', page_id: 'test_id' })

      expect {
        cli.invoke(:sync, [file_path], {
          api_key: api_key,
          database_id: database_id,
          unique_value: 'custom_value'
        })
      }.not_to raise_error
    end

    it 'passes custom title option' do
      syncer = instance_double(Synotion::Syncer)
      allow(Synotion::Syncer).to receive(:new).and_return(syncer)

      expect(syncer).to receive(:sync).with(
        file_path,
        hash_including(title: 'Custom Title')
      ).and_return({ action: 'created', page_id: 'test_id' })

      expect {
        cli.invoke(:sync, [file_path], {
          api_key: api_key,
          database_id: database_id,
          title: 'Custom Title'
        })
      }.not_to raise_error
    end

    context 'with config file' do
      let(:config_file) { '.notion-sync.yml' }
      let(:config_data) do
        {
          'notion_api_key' => api_key,
          'database_id' => database_id,
          'update_mode' => 'replace'
        }
      end

      before do
        allow(File).to receive(:exist?).with(config_file).and_return(true)
        allow(YAML).to receive(:load_file).with(config_file).and_return(config_data)
      end

      after do
        Synotion.reset_configuration!
      end

      it 'loads configuration from file' do
        syncer = instance_double(Synotion::Syncer)
        allow(Synotion::Syncer).to receive(:new).and_return(syncer)
        allow(syncer).to receive(:sync).and_return({ action: 'updated', page_id: 'test_id' })

        expect {
          cli.invoke(:sync, [file_path], { config: config_file })
        }.not_to raise_error

        expect(Synotion.configuration.notion_api_key).to eq(api_key)
        expect(Synotion.configuration.database_id).to eq(database_id)
        expect(Synotion.configuration.update_mode).to eq(:replace)
      end

      it 'handles config file errors gracefully' do
        allow(YAML).to receive(:load_file).and_raise(StandardError, 'Invalid YAML')

        syncer = instance_double(Synotion::Syncer)
        allow(Synotion::Syncer).to receive(:new).and_return(syncer)
        allow(syncer).to receive(:sync).and_return({ action: 'created', page_id: 'test_id' })

        expect {
          cli.invoke(:sync, [file_path], {
            config: config_file,
            api_key: api_key,
            database_id: database_id
          })
        }.to output(/Warning: Failed to load config file/).to_stdout
      end
    end
  end

  describe '#version' do
    it 'displays version' do
      expect {
        cli.invoke(:version)
      }.to output(/Synotion version #{Synotion::VERSION}/).to_stdout
    end
  end
end
