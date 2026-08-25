# frozen_string_literal: true

require 'rails_helper'

# Fork Valcenter: custom role 'team_manage' — gestão completa de Times.
RSpec.describe 'TeamPolicy (team_manage)', type: :policy do
  let(:account) { create(:account) }
  let(:team) { create(:team, account: account) }

  let(:team_manage_role) { create(:custom_role, account: account, permissions: ['team_manage']) }
  let(:manager) { create(:user) }
  let(:manager_account_user) do
    create(:account_user, user: manager, account: account, role: :agent, custom_role: team_manage_role)
  end
  let(:manager_context) { { user: manager, account: account, account_user: manager_account_user } }

  let(:plain_agent) { create(:user) }
  let(:plain_agent_account_user) { create(:account_user, user: plain_agent, account: account, role: :agent) }
  let(:plain_agent_context) { { user: plain_agent, account: account, account_user: plain_agent_account_user } }

  describe TeamPolicy do
    permissions :create?, :update?, :destroy? do
      it 'permits a user with team_manage' do
        expect(described_class).to permit(manager_context, team)
      end

      it 'denies a plain agent' do
        expect(described_class).not_to permit(plain_agent_context, team)
      end
    end
  end

  describe TeamMemberPolicy do
    permissions :create?, :update?, :destroy? do
      it 'permits a user with team_manage to manage members' do
        expect(described_class).to permit(manager_context, team)
      end

      it 'denies a plain agent' do
        expect(described_class).not_to permit(plain_agent_context, team)
      end
    end
  end
end
