require 'rails_helper'

RSpec.describe Contacts::PhoneSearchTerm do
  describe '.fragment' do
    it 'keeps the last 8 digits of a masked phone' do
      expect(described_class.fragment('(11) 97313-8202')).to eq('73138202')
    end

    it 'matches the number with or without the 9th digit and country code' do
      expect(described_class.fragment('+55 11 9 7313-8202')).to eq('73138202')
      expect(described_class.fragment('973138202')).to eq('73138202')
    end

    it 'keeps short digit terms as they are' do
      expect(described_class.fragment('7313-8')).to eq('73138')
    end

    it 'ignores terms that are not phone-like' do
      expect(described_class.fragment('ana')).to be_nil
      expect(described_class.fragment('CCPL00411')).to be_nil
      expect(described_class.fragment('  ')).to be_nil
      expect(described_class.fragment('()-')).to be_nil
    end
  end
end
