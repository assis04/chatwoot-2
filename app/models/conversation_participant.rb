# == Schema Information
#
# Table name: conversation_participants
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_conversation_participants_on_account_id                   (account_id)
#  index_conversation_participants_on_conversation_id              (conversation_id)
#  index_conversation_participants_on_user_id                      (user_id)
#  index_conversation_participants_on_user_id_and_conversation_id  (user_id,conversation_id) UNIQUE
#
class ConversationParticipant < ApplicationRecord
  validates :account_id, presence: true
  validates :conversation_id, presence: true
  validates :user_id, presence: true
  validates :user_id, uniqueness: { scope: [:conversation_id] }
  validate :ensure_inbox_access

  belongs_to :account
  belongs_to :conversation
  belongs_to :user

  before_validation :ensure_account_id
  after_commit :invalidate_filtered_unread_count_visibility, on: [:create, :destroy]

  private

  def ensure_account_id
    self.account_id = conversation&.account_id
  end

  def ensure_inbox_access
    return unless conversation

    # Fork Valcenter: em modo Digisac (department_visibility_enabled) qualquer
    # agente da conta pode participar de qualquer conversa, independente de ser
    # membro da caixa — espelha o ParticipantsController#allowed_participant_ids
    # e o AssignableAgentsController#index. Sem isto o seletor lista o agente, o
    # controller aceita, mas esta validacao do model rejeita ("must have inbox
    # access"). A fronteira entre contas continua: so agentes da propria conta.
    if department_visibility_enabled?
      errors.add(:user, 'must have inbox access') unless conversation.account.users.exists?(id: user_id)
      return
    end

    errors.add(:user, 'must have inbox access') if conversation.inbox.assignable_agents.exclude?(user)
  end

  def department_visibility_enabled?
    ca = conversation.account.custom_attributes
    ca.is_a?(Hash) && ca['department_visibility_enabled']
  end

  def invalidate_filtered_unread_count_visibility
    ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account).user_visibility_changed!(user_id: user_id)
  end
end
