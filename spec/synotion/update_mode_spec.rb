RSpec.describe Synotion::UpdateMode do
  describe '::ALL' do
    it 'includes all update modes' do
      expect(described_class::ALL).to contain_exactly(
        :create,
        :append,
        :replace,
        :upsert
      )
    end
  end

  describe '.valid?' do
    it 'returns true for valid modes' do
      expect(described_class.valid?(:create)).to be true
      expect(described_class.valid?(:append)).to be true
      expect(described_class.valid?(:replace)).to be true
      expect(described_class.valid?(:upsert)).to be true
    end

    it 'returns false for invalid modes' do
      expect(described_class.valid?(:invalid)).to be false
      expect(described_class.valid?(:delete)).to be false
    end
  end
end
