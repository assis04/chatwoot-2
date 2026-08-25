# frozen_string_literal: true

require 'rails_helper'

# Fork Valcenter: custom role 'inbox_manage' — gerencia caixas EXISTENTES
# (configurações + colaboradores), mas NUNCA cria/apaga caixa.
RSpec.describe 'InboxPolicy (inbox_manage)', type: :policy do
  subject(:inbox_policy) { InboxPolicy }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }

  let(:inbox_manage_role) { create(:custom_role, account: account, permissions: ['inbox_manage']) }
  let(:manager) { create(:user) }
  let(:manager_account_user) do
    create(:account_user, user: manager, account: account, role: :agent, custom_role: inbox_manage_role)
  end
  let(:manager_context) { { user: manager, account: account, account_user: manager_account_user } }

  let(:plain_agent) { create(:user) }
  let(:plain_agent_account_user) { create(:account_user, user: plain_agent, account: account, role: :agent) }
  let(:plain_agent_context) { { user: plain_agent, account: account, account_user: plain_agent_account_user } }

  permissions :update?, :manage_members? do
    it 'permits a user with inbox_manage' do
      expect(inbox_policy).to permit(manager_context, inbox)
    end

    it 'denies a plain agent' do
      expect(inbox_policy).not_to permit(plain_agent_context, inbox)
    end
  end

  # Limite crítico: inbox_manage NÃO pode criar nem apagar caixas (segue só-admin).
  permissions :create?, :destroy? do
    it 'denies a user with inbox_manage (stays admin-only)' do
      expect(inbox_policy).not_to permit(manager_context, inbox)
    end
  end
end
