require 'rails_helper'

# Fork Valcenter: destinatários dos eventos ao vivo respeitam a hierarquia de
# visibilidade de conversa (custom_roles). Garante que o agente restrito
# (conversation_participating_manage) NÃO recebe push de conversa que não é dele,
# enquanto gerente (conversation_manage) e agente comum (sem função) recebem tudo.
RSpec.describe ActionCableListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account, custom_attributes: { 'department_visibility_enabled' => true }) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }

  let(:gerente_role) { create(:custom_role, account: account, permissions: ['conversation_manage']) }
  let(:agente_role) { create(:custom_role, account: account, permissions: ['conversation_participating_manage']) }

  let(:gerente) { create(:user) }
  let(:agente) { create(:user) }
  let(:comum) { create(:user) } # agente comum, sem função personalizada

  before do
    create(:account_user, account: account, user: gerente, role: :agent, custom_role: gerente_role)
    create(:account_user, account: account, user: agente, role: :agent, custom_role: agente_role)
    create(:account_user, account: account, user: comum, role: :agent)
    [gerente, agente, comum].each do |u|
      create(:inbox_member, inbox: inbox, user: u)
      create(:team_member, team: team, user: u)
    end
  end

  def visible_ids(conversation)
    listener.send(:conversation_visible_members, account, conversation).map(&:id)
  end

  describe '#conversation_visible_members' do
    it 'exclui o agente restrito de conversa nao-atribuida (gerente e comum recebem)' do
      conv = create(:conversation, account: account, inbox: inbox, team: team, assignee: nil)
      ids = visible_ids(conv)
      expect(ids).not_to include(agente.id)
      expect(ids).to include(gerente.id, comum.id)
    end

    it 'inclui o agente quando a conversa e atribuida a ele' do
      conv = create(:conversation, account: account, inbox: inbox, team: team, assignee: agente)
      expect(visible_ids(conv)).to include(agente.id, gerente.id, comum.id)
    end

    it 'exclui o agente quando a conversa e atribuida a outro' do
      conv = create(:conversation, account: account, inbox: inbox, team: team, assignee: gerente)
      expect(visible_ids(conv)).not_to include(agente.id)
      expect(visible_ids(conv)).to include(gerente.id, comum.id)
    end

    it 'inclui o agente quando ele e participante' do
      conv = create(:conversation, account: account, inbox: inbox, team: team, assignee: nil)
      create(:conversation_participant, account: account, conversation: conv, user: agente)
      expect(visible_ids(conv)).to include(agente.id)
    end

    it 'mantem o agente restrito vendo a conversa dele mesmo resolvida' do
      conv = create(:conversation, account: account, inbox: inbox, team: team, assignee: agente, status: :resolved)
      expect(visible_ids(conv)).to include(agente.id)
    end
  end
end
