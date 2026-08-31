require 'rails_helper'

# Fork Valcenter: sincroniza o número do WhatsApp das caixas Evolution
# (Channel::Api) a partir do ownerJid da instância -> additional_attributes.
RSpec.describe Evolution::InstanceNumberSyncService do
  let(:api_url) { 'http://evolution:8080' }
  let(:fetch_url) { "#{api_url}/instance/fetchInstances" }

  let(:instances_body) do
    [
      # nome com espaço (webhook traz %20); ownerJid -> +5511987654321
      { 'name' => 'Valcenter Guarulhos', 'ownerJid' => '5511987654321@s.whatsapp.net', 'connectionStatus' => 'open' },
      # formato embrulhado { instance: {...} } + fallback pro campo 'number' (fixo)
      { 'instance' => { 'name' => 'Pre-vendas', 'number' => '551133334444' } }
    ].to_json
  end

  def set_env(url, key)
    ENV['EVOLUTION_API_URL'] = url
    ENV['EVOLUTION_API_KEY'] = key
  end

  before do
    @env_backup = ENV.to_hash.slice('EVOLUTION_API_URL', 'EVOLUTION_API_KEY')
    set_env(api_url, 'test-key')
  end

  after do
    ENV.delete('EVOLUTION_API_URL')
    ENV.delete('EVOLUTION_API_KEY')
    @env_backup.each { |k, v| ENV[k] = v }
  end

  def stub_fetch(body = instances_body, status: 200)
    stub_request(:get, fetch_url).to_return(
      status: status, body: body, headers: { 'Content-Type' => 'application/json' }
    )
  end

  describe '#perform' do
    it 'grava o número (E.164) a partir do ownerJid, casando pelo webhook URL-decoded' do
      stub_fetch
      channel = create(:channel_api, webhook_url: 'https://x/evolution/chatwoot/webhook/Valcenter%20Guarulhos')

      expect(described_class.new.perform).to eq(1)
      expect(channel.reload.additional_attributes['phone_number']).to eq('+5511987654321')
    end

    it 'suporta o formato embrulhado e o fallback pro campo number' do
      stub_fetch
      channel = create(:channel_api, webhook_url: 'https://x/evolution/chatwoot/webhook/Pre-vendas')

      described_class.new.perform
      expect(channel.reload.additional_attributes['phone_number']).to eq('+551133334444')
    end

    it 'faz merge — preserva as outras chaves do additional_attributes' do
      stub_fetch
      channel = create(:channel_api,
                       webhook_url: 'https://x/evolution/chatwoot/webhook/Valcenter%20Guarulhos',
                       additional_attributes: { 'existing' => 'keep' })

      described_class.new.perform
      attrs = channel.reload.additional_attributes
      expect(attrs['existing']).to eq('keep')
      expect(attrs['phone_number']).to eq('+5511987654321')
    end

    it 'não altera caixa sem instância correspondente' do
      stub_fetch
      channel = create(:channel_api,
                       webhook_url: 'https://x/evolution/chatwoot/webhook/Inexistente',
                       additional_attributes: { 'existing' => 'keep' })

      described_class.new.perform
      expect(channel.reload.additional_attributes).to eq({ 'existing' => 'keep' })
    end

    it 'é idempotente — segunda passada não conta atualização' do
      stub_fetch
      create(:channel_api, webhook_url: 'https://x/evolution/chatwoot/webhook/Valcenter%20Guarulhos')

      expect(described_class.new.perform).to eq(1)
      expect(described_class.new.perform).to eq(0)
    end

    it 'é no-op quando a Evolution não está configurada (sem env)' do
      set_env('', '')
      channel = create(:channel_api, webhook_url: 'https://x/evolution/chatwoot/webhook/Valcenter%20Guarulhos')

      expect(described_class.new.perform).to be_nil
      expect(channel.reload.additional_attributes).to eq({})
      expect(a_request(:get, fetch_url)).not_to have_been_made
    end

    it 'não levanta quando a Evolution responde erro' do
      stub_fetch('boom', status: 500)
      create(:channel_api, webhook_url: 'https://x/evolution/chatwoot/webhook/Valcenter%20Guarulhos')

      expect { described_class.new.perform }.not_to raise_error
    end
  end
end
