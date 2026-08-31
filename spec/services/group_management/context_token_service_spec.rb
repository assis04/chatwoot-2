require 'rails_helper'

# Fork Valcenter: o token de contexto da Gestão de Grupos NUNCA pode conceder
# escopo além da conta — senão uma conta enxerga os números/grupos de outra.
RSpec.describe GroupManagement::ContextTokenService do
  let(:secret) { 'x' * 40 }
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }

  let!(:inbox_a1) { create(:inbox, account: account) }
  let!(:inbox_a2) { create(:inbox, account: account) }
  let!(:inbox_other) { create(:inbox, account: other_account) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('GROUP_CTX_SECRET').and_return(secret)
  end

  def decode(token)
    JWT.decode(token, secret, true, algorithm: 'HS256').first
  end

  context 'quando administrador da conta' do
    let(:admin) { create(:user) }

    before { create(:account_user, account: account, user: admin, role: :administrator) }

    it 'manda TODAS as caixas da conta e NENHUMA de outra conta' do
      payload = decode(described_class.new(account: account, user: admin).generate)

      expect(payload['is_admin']).to be(true)
      expect(payload['account_id']).to eq(account.id)
      expect(payload['inbox_ids']).to contain_exactly(inbox_a1.id, inbox_a2.id)
      expect(payload['inbox_ids']).not_to include(inbox_other.id)
    end

    it 'nunca manda lista vazia (que o app externo leria como "tudo global")' do
      payload = decode(described_class.new(account: account, user: admin).generate)
      expect(payload['inbox_ids']).not_to be_empty
    end
  end

  context 'quando agente' do
    let(:agent) { create(:user) }

    before do
      create(:account_user, account: account, user: agent, role: :agent)
      create(:inbox_member, user: agent, inbox: inbox_a1)
    end

    it 'manda só as caixas que o agente participa nesta conta' do
      payload = decode(described_class.new(account: account, user: agent).generate)

      expect(payload['is_admin']).to be(false)
      expect(payload['inbox_ids']).to contain_exactly(inbox_a1.id)
    end
  end
end
