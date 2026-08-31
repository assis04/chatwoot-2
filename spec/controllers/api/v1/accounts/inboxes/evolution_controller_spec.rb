require 'rails_helper'

# Fork Valcenter: endpoints de status/QR da Evolution. Foco: gate de autorização
# (admin OU inbox_manage), no-op quando não configurado, e o happy path do QR.
RSpec.describe 'Inboxes Evolution API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  let(:manager) do
    user = create(:user, account: account, role: :agent)
    role = create(:custom_role, account: account, permissions: ['inbox_manage'])
    user.account_users.find_by(account: account).update!(custom_role: role)
    user
  end

  let!(:channel) do
    create(:channel_api, account: account, webhook_url: 'https://x/evolution/chatwoot/webhook/Guarulhos')
  end
  let(:inbox) { channel.inbox }

  let(:api_url) { 'http://evolution:8080' }

  before do
    @env = ENV.to_hash.slice('EVOLUTION_API_URL', 'EVOLUTION_API_KEY')
    ENV['EVOLUTION_API_URL'] = api_url
    ENV['EVOLUTION_API_KEY'] = 'test-key'
  end

  after do
    ENV.delete('EVOLUTION_API_URL')
    ENV.delete('EVOLUTION_API_KEY')
    @env.each { |k, v| ENV[k] = v }
  end

  def stub_fetch(instances)
    stub_request(:get, "#{api_url}/instance/fetchInstances")
      .to_return(status: 200, body: instances.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe 'GET /inboxes/evolution/statuses' do
    before { stub_fetch([{ 'name' => 'Guarulhos', 'connectionStatus' => 'open' }]) }

    it 'nega usuário não autenticado' do
      get "/api/v1/accounts/#{account.id}/inboxes/evolution/statuses"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'nega agente comum (sem inbox_manage)' do
      get "/api/v1/accounts/#{account.id}/inboxes/evolution/statuses",
          headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'permite admin e devolve o status por caixa' do
      get "/api/v1/accounts/#{account.id}/inboxes/evolution/statuses",
          headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['statuses'][inbox.id.to_s]).to eq('open')
    end

    it 'permite gestor com inbox_manage' do
      get "/api/v1/accounts/#{account.id}/inboxes/evolution/statuses",
          headers: manager.create_new_auth_token, as: :json
      expect(response).to have_http_status(:success)
    end

    it 'retorna 503 quando a Evolution não está configurada' do
      ENV['EVOLUTION_API_URL'] = ''
      get "/api/v1/accounts/#{account.id}/inboxes/evolution/statuses",
          headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:service_unavailable)
    end
  end

  describe 'POST /inboxes/:id/evolution/connect' do
    it 'devolve o QR (base64) quando desconectada' do
      stub_request(:get, "#{api_url}/instance/connect/Guarulhos")
        .to_return(status: 200,
                   body: { base64: 'data:image/png;base64,AAA', code: '2@abc', pairingCode: nil }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/evolution/connect",
           headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body['status']).to eq('qrcode')
      expect(body['qrcode']).to start_with('data:image/png;base64,')
    end

    it 'devolve status (sem QR) quando já conectada' do
      stub_request(:get, "#{api_url}/instance/connect/Guarulhos")
        .to_return(status: 200,
                   body: { instance: { instanceName: 'Guarulhos', state: 'open' } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/evolution/connect",
           headers: admin.create_new_auth_token, as: :json

      expect(JSON.parse(response.body)['status']).to eq('open')
    end

    it 'nega agente comum' do
      post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/evolution/connect",
           headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
