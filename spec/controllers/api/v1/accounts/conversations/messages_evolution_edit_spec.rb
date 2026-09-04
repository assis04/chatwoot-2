require 'rails_helper'

# Fork Valcenter: edição de mensagem enviada no WhatsApp via Evolution.
RSpec.describe 'Messages Evolution Edit API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:channel) do
    create(:channel_api, account: account, webhook_url: 'https://x/evolution/chatwoot/webhook/Guarulhos')
  end
  let(:inbox) { channel.inbox }
  let(:contact) { create(:contact, account: account, phone_number: '+5511999998888') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5511999998888') }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)
  end
  let(:api_url) { 'http://evolution:8080' }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    @env = ENV.to_hash.slice('EVOLUTION_API_URL', 'EVOLUTION_API_KEY')
    ENV['EVOLUTION_API_URL'] = api_url
    ENV['EVOLUTION_API_KEY'] = 'test-key'
  end

  after do
    ENV.delete('EVOLUTION_API_URL')
    ENV.delete('EVOLUTION_API_KEY')
    @env.each { |k, v| ENV[k] = v }
  end

  def edit_url(msg)
    "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/messages/#{msg.id}/evolution_edit"
  end

  def outgoing(source_id: 'WAID:ABC123', created_at: Time.current)
    m = create(:message, account: account, inbox: inbox, conversation: conversation,
                         message_type: :outgoing, content: 'texto original', source_id: source_id)
    m.update_columns(created_at: created_at)
    m
  end

  context 'quando mensagem de saída do WhatsApp dentro da janela' do
    before do
      stub_request(:post, "#{api_url}/chat/updateMessage/Guarulhos")
        .to_return(status: 200, body: { key: { id: 'ABC123' } }.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'edita na Evolution, atualiza o content e guarda o original' do
      msg = outgoing
      post edit_url(msg), params: { content: 'texto corrigido' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(msg.reload.content).to eq('texto corrigido')
      expect(msg.content_attributes.dig('edited', 'original')).to eq('texto original')
      expect(a_request(:post, "#{api_url}/chat/updateMessage/Guarulhos")).to have_been_made
    end
  end

  it 'nega usuário não autenticado' do
    post edit_url(outgoing), params: { content: 'x' }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejeita mensagem recebida (não é do agente)' do
    msg = create(:message, account: account, inbox: inbox, conversation: conversation,
                           message_type: :incoming, content: 'oi', source_id: 'WAID:IN')
    post edit_url(msg), params: { content: 'x' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejeita mensagem fora da janela de 15 min' do
    msg = outgoing(created_at: 20.minutes.ago)
    post edit_url(msg), params: { content: 'x' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejeita mensagem sem referência WAID' do
    msg = outgoing(source_id: nil)
    post edit_url(msg), params: { content: 'y' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejeita texto vazio' do
    post edit_url(outgoing), params: { content: '   ' }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
