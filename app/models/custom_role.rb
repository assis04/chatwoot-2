# == Schema Information
#
# Table name: custom_roles
#
#  id          :bigint           not null, primary key
#  description :string
#  name        :string
#  permissions :text             default([]), is an Array
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_custom_roles_on_account_id  (account_id)
#

# Fork Valcenter: reimplementação PRÓPRIA (Community) do custom_roles. Antes vinha
# do overlay enterprise (feature premium/licenciada); reconstruímos como código
# nosso, na base, pra rodar em Community Edition sem depender do EE.
#
# Permissões disponíveis:
# - 'conversation_manage': gerencia todas as conversas.
# - 'conversation_unassigned_manage': gerencia conversas não atribuídas + as suas.
# - 'conversation_participating_manage': gerencia as conversas em que participa/é atribuído.
# - 'contact_manage': gerencia contatos (export/import).
# - 'report_manage': gerencia relatórios.
# - 'knowledge_base_manage': gerencia portais da base de conhecimento.
# - 'agent_manage': cria/edita/remove AGENTES (nunca administradores — travado no
#   AgentsController). Onboarding sem ser admin.
# - 'team_manage': gestão completa de Times (criar/editar/apagar + membros).
# - 'inbox_manage': vê/edita config e colaboradores de caixas EXISTENTES (não cria
#   nem apaga caixa — isso segue só-admin no InboxPolicy).
class CustomRole < ApplicationRecord
  belongs_to :account
  has_many :account_users, dependent: :nullify

  before_destroy :capture_filtered_unread_count_user_ids, prepend: true
  after_update_commit :invalidate_filtered_unread_count_visibility_update, if: :filtered_unread_count_permissions_changed?
  after_destroy_commit :invalidate_filtered_unread_count_visibility_destroy

  PERMISSIONS = %w[
    conversation_manage
    conversation_unassigned_manage
    conversation_participating_manage
    contact_manage
    report_manage
    knowledge_base_manage
    agent_manage
    team_manage
    inbox_manage
  ].freeze

  validates :name, presence: true
  validates :permissions, inclusion: { in: PERMISSIONS }

  private

  def filtered_unread_count_permissions_changed?
    previous_changes.key?('permissions')
  end

  def capture_filtered_unread_count_user_ids
    @filtered_unread_count_user_ids = account_users.pluck(:user_id)
  end

  def invalidate_filtered_unread_count_visibility_update
    invalidate_filtered_unread_count_visibility(account_users.pluck(:user_id))
  end

  def invalidate_filtered_unread_count_visibility_destroy
    invalidate_filtered_unread_count_visibility(@filtered_unread_count_user_ids)
  end

  def invalidate_filtered_unread_count_visibility(user_ids)
    invalidator = ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account)
    visibility_changed = invalidator.users_visibility_changed!(user_ids: user_ids)

    dispatch_account_cache_invalidated if visibility_changed
  end

  def dispatch_account_cache_invalidated
    Rails.configuration.dispatcher.dispatch(ACCOUNT_CACHE_INVALIDATED, Time.zone.now, account: account, cache_keys: account.cache_keys)
  end
end
