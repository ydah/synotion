RSpec.describe Synotion do
  it "has a version number" do
    expect(Synotion::VERSION).not_to be nil
  end

  describe '.configure' do
    after do
      Synotion.reset_configuration!
    end

    it 'allows global configuration' do
      Synotion.configure do |config|
        config.notion_api_key = 'test_key'
        config.database_id = 'test_db'
      end

      expect(Synotion.configuration.notion_api_key).to eq('test_key')
      expect(Synotion.configuration.database_id).to eq('test_db')
    end
  end

  describe '.reset_configuration!' do
    it 'resets configuration to defaults' do
      Synotion.configure do |config|
        config.notion_api_key = 'test_key'
      end

      Synotion.reset_configuration!

      expect(Synotion.configuration.notion_api_key).to be_nil
      expect(Synotion.configuration.update_mode).to eq(Synotion::UpdateMode::UPSERT)
    end
  end
end
