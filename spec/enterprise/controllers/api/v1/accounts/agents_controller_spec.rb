require 'rails_helper'

RSpec.describe 'Agents API', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let!(:admin) { create(:user, custom_attributes: { test: 'test' }, account: account, role: :administrator) }

  describe 'POST /api/v1/accounts/{account.id}/agents' do
    context 'when the account has reached its agent limit' do
      params = { name: 'NewUser', email: Faker::Internet.email, role: :agent }

      before do
        account.update(limits: { agents: 4 })
        create_list(:user, 4, account: account, role: :agent)
      end

      it 'prevents adding a new agent and returns a payment required status' do
        post "/api/v1/accounts/#{account.id}/agents", params: params, headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:payment_required)
        expect(response.body).to include('Account limit exceeded. Please purchase more licenses')
      end

      it 'prevents adding an agent if the last seat is consumed before creation' do
        account.update!(limits: { agents: account.account_users.count + 1 })
        competing_agent_created = false

        allow(AgentBuilder).to receive(:new).and_wrap_original do |method, *args|
          unless competing_agent_created
            create(:user, account: account, role: :agent)
            competing_agent_created = true
          end

          method.call(*args)
        end

        post "/api/v1/accounts/#{account.id}/agents", params: params, headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:payment_required)
        expect(response.body).to include('Account limit exceeded. Please purchase more licenses')
        expect(User.from_email(params[:email])).to be_nil
        expect(account.account_users.count).to eq(account.usage_limits[:agents])
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/agents/bulk_create' do
    let(:emails) { ['test1@example.com', 'test2@example.com', 'test3@example.com'] }
    let(:bulk_create_params) { { emails: emails } }

    context 'when exceeding agent limit' do
      it 'prevents creating agents and returns a payment required status' do
        # Set the limit to be less than the number of emails
        account.update(limits: { agents: 2 })

        expect do
          post "/api/v1/accounts/#{account.id}/agents/bulk_create", params: bulk_create_params, headers: admin.create_new_auth_token
        end.not_to change(User, :count)

        expect(response).to have_http_status(:payment_required)
        expect(response.body).to include('Account limit exceeded. Please purchase more licenses')
      end
    end

    context 'when onboarding step is present in account custom attributes' do
      it 'removes onboarding step from account custom attributes' do
        account.update(custom_attributes: { onboarding_step: 'completed' })

        post "/api/v1/accounts/#{account.id}/agents/bulk_create", params: bulk_create_params, headers: admin.create_new_auth_token

        expect(account.reload.custom_attributes).not_to include('onboarding_step')
      end
    end
  end

  # Fork Valcenter: custom role 'agent_manage' — pode gerenciar AGENTES e atribuir
  # QUALQUER função da conta, nunca ADMINISTRADOR (modelo RH/onboarding).
  describe 'custom role agent_manage' do
    let(:agent_manage_role) { create(:custom_role, account: account, permissions: ['agent_manage']) }
    let(:manager) { create(:user, account: account, role: :agent) }
    let(:manager_headers) { manager.create_new_auth_token }

    before do
      account.update!(limits: { agents: 100 })
      account.account_users.find_by(user_id: manager.id).update!(custom_role: agent_manage_role)
    end

    describe 'POST /api/v1/accounts/{account.id}/agents' do
      it 'allows creating a plain agent' do
        email = "new-#{SecureRandom.hex(4)}@example.com"

        expect do
          post "/api/v1/accounts/#{account.id}/agents",
               params: { name: 'New Agent', email: email, role: :agent }, headers: manager_headers, as: :json
        end.to change(User, :count).by(1)

        expect(response).to have_http_status(:success)
        expect(account.account_users.find_by(user_id: User.from_email(email).id).role).to eq('agent')
      end

      it 'forbids creating an administrator (privilege escalation)' do
        email = "admin-#{SecureRandom.hex(4)}@example.com"

        expect do
          post "/api/v1/accounts/#{account.id}/agents",
               params: { name: 'Hax', email: email, role: :administrator }, headers: manager_headers, as: :json
        end.not_to change(User, :count)

        expect(response).to have_http_status(:unauthorized)
        expect(User.from_email(email)).to be_nil
      end

      it 'allows assigning any account custom role, even one more powerful than its own' do
        powerful_role = create(:custom_role, account: account, permissions: ['report_manage'])
        email = "role-#{SecureRandom.hex(4)}@example.com"

        post "/api/v1/accounts/#{account.id}/agents",
             params: { name: 'Role', email: email, custom_role_id: powerful_role.id }, headers: manager_headers, as: :json

        expect(response).to have_http_status(:success)
        expect(account.account_users.find_by(user_id: User.from_email(email).id).custom_role_id).to eq(powerful_role.id)
      end

      it 'forbids assigning a custom role from another account (cross-tenant)' do
        foreign_role = create(:custom_role, account: create(:account), permissions: ['agent_manage'])
        email = "ext-#{SecureRandom.hex(4)}@example.com"

        post "/api/v1/accounts/#{account.id}/agents",
             params: { name: 'Ext', email: email, custom_role_id: foreign_role.id }, headers: manager_headers, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'PATCH /api/v1/accounts/{account.id}/agents/{id}' do
      it 'forbids promoting an existing agent to administrator' do
        target = create(:user, account: account, role: :agent)

        patch "/api/v1/accounts/#{account.id}/agents/#{target.id}",
              params: { role: :administrator }, headers: manager_headers, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(account.account_users.find_by(user_id: target.id).role).to eq('agent')
      end

      it 'forbids editing an administrator' do
        target_admin = create(:user, account: account, role: :administrator)

        patch "/api/v1/accounts/#{account.id}/agents/#{target_admin.id}",
              params: { name: 'Hacked' }, headers: manager_headers, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(target_admin.reload.name).not_to eq('Hacked')
      end

      it 'allows assigning any account custom role to an existing agent' do
        target = create(:user, account: account, role: :agent)
        powerful_role = create(:custom_role, account: account, permissions: ['conversation_manage'])

        patch "/api/v1/accounts/#{account.id}/agents/#{target.id}",
              params: { custom_role_id: powerful_role.id }, headers: manager_headers, as: :json

        expect(response).to have_http_status(:success)
        expect(account.account_users.find_by(user_id: target.id).custom_role_id).to eq(powerful_role.id)
      end

      it 'forbids assigning a custom role from another account (cross-tenant)' do
        target = create(:user, account: account, role: :agent)
        foreign_role = create(:custom_role, account: create(:account), permissions: ['agent_manage'])

        patch "/api/v1/accounts/#{account.id}/agents/#{target.id}",
              params: { custom_role_id: foreign_role.id }, headers: manager_headers, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    describe 'GET /api/v1/accounts/{account.id}/custom_roles' do
      it 'allows an agent_manage user to list custom roles (to assign them)' do
        create(:custom_role, account: account, permissions: ['conversation_manage'])

        get "/api/v1/accounts/#{account.id}/custom_roles", headers: manager_headers, as: :json

        expect(response).to have_http_status(:success)
      end
    end

    describe 'DELETE /api/v1/accounts/{account.id}/agents/{id}' do
      it 'forbids deleting an administrator' do
        target_admin = create(:user, account: account, role: :administrator)

        delete "/api/v1/accounts/#{account.id}/agents/#{target_admin.id}", headers: manager_headers, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(account.account_users.exists?(user_id: target_admin.id)).to be(true)
      end

      it 'allows deleting a plain agent' do
        target = create(:user, account: account, role: :agent)

        delete "/api/v1/accounts/#{account.id}/agents/#{target.id}", headers: manager_headers, as: :json

        expect(response).to have_http_status(:success)
        expect(account.account_users.exists?(user_id: target.id)).to be(false)
      end
    end
  end
end
