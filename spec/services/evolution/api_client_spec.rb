require 'rails_helper'

# Fork Valcenter: helpers de parsing do client da Evolution (lógica pura).
RSpec.describe Evolution::ApiClient do
  describe '.instance_from_webhook' do
    it 'extrai e decodifica o nome da instância do webhook_url' do
      expect(described_class.instance_from_webhook('https://x/evolution/chatwoot/webhook/Valcenter%20Guarulhos'))
        .to eq('Valcenter Guarulhos')
      expect(described_class.instance_from_webhook('https://x/webhook/Log%C3%ADstica')).to eq('Logística')
    end

    it 'retorna nil para valor em branco' do
      expect(described_class.instance_from_webhook(nil)).to be_nil
      expect(described_class.instance_from_webhook('')).to be_nil
    end
  end

  describe '.index_by_name' do
    it 'normaliza o formato direto e o embrulhado, indexando pelo nome' do
      idx = described_class.index_by_name(
        [
          { 'name' => 'A', 'x' => 1 },
          { 'instance' => { 'name' => 'B', 'y' => 2 } }
        ]
      )
      expect(idx.keys).to contain_exactly('A', 'B')
      expect(idx['B']['y']).to eq(2)
    end

    it 'aceita entrada não-array sem levantar' do
      expect(described_class.index_by_name(nil)).to eq({})
    end
  end

  describe '.number_from_instance' do
    it 'usa ownerJid em E.164, com fallback pro campo number' do
      expect(described_class.number_from_instance('ownerJid' => '5511987654321@s.whatsapp.net')).to eq('+5511987654321')
      expect(described_class.number_from_instance('number' => '551133334444')).to eq('+551133334444')
    end

    it 'retorna nil sem número' do
      expect(described_class.number_from_instance({})).to be_nil
      expect(described_class.number_from_instance(nil)).to be_nil
    end
  end

  describe '.normalize_status' do
    it 'mapeia os estados da Evolution' do
      expect(described_class.normalize_status('open')).to eq('open')
      expect(described_class.normalize_status('connecting')).to eq('connecting')
      expect(described_class.normalize_status('close')).to eq('close')
      expect(described_class.normalize_status('disconnected')).to eq('close')
      expect(described_class.normalize_status('coisa')).to eq('unknown')
      expect(described_class.normalize_status(nil)).to eq('unknown')
    end
  end

  describe '.configured?' do
    it 'exige URL e KEY' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('EVOLUTION_API_URL', '').and_return('http://evo:8080')
      allow(ENV).to receive(:fetch).with('EVOLUTION_API_KEY', '').and_return('')
      expect(described_class.configured?).to be(false)

      allow(ENV).to receive(:fetch).with('EVOLUTION_API_KEY', '').and_return('k')
      expect(described_class.configured?).to be(true)
    end
  end
end
