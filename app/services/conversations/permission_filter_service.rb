class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account)
    @conversations = conversations
    @user = user
    @account = account
  end

  def perform
    return conversations if user_role == 'administrator'
    return filter_by_permissions(permissions) if user_has_custom_role?

    accessible_conversations
  end

  private

  # Fork Valcenter: custom_roles (Community) — filtragem de conversa por permissão,
  # com hierarquia manage > unassigned_manage > participating_manage. Portado do
  # overlay enterprise pra base.
  def user_has_custom_role?
    user_role == 'agent' && account_user&.custom_role_id.present?
  end

  def permissions
    account_user&.permissions || []
  end

  def filter_by_permissions(permissions)
    if permissions.include?('conversation_manage')
      accessible_conversations
    elsif permissions.include?('conversation_unassigned_manage')
      filter_unassigned_and_mine
    elsif permissions.include?('conversation_participating_manage')
      filter_participating_and_mine
    else
      Conversation.none
    end
  end

  def filter_participating_and_mine
    conversations = accessible_conversations
    participant_conversation_ids = ConversationParticipant.where(account_id: account.id, user_id: user.id).select(:conversation_id)

    conversations
      .where(assignee_id: user.id)
      .or(conversations.where(id: participant_conversation_ids))
  end

  def filter_unassigned_and_mine
    accessible_conversations.where(assignee_id: [nil, user.id])
  end

  # Fork customization — Digisac-style visibility. When the account opts in
  # (custom_attributes.department_visibility_enabled), an agent sees a conversation
  # if it is in one of their INBOXES, or ASSIGNED to them, or in one of their
  # TEAMS — the last two allow a conversation to be transferred to a person or a
  # department across numbers and still be seen/answered by the recipient.
  # Custom roles (participating/unassigned/manage) still refine this set on top.
  # Otherwise the legacy inbox-only rule is used, so the flag is a safe switch.
  def accessible_conversations
    return legacy_accessible_conversations unless department_visibility_enabled?

    inbox_ids = user.inboxes.where(account_id: account.id).pluck(:id)
    team_ids  = user.teams.where(account_id: account.id).pluck(:id)
    conversations.where(
      'conversations.inbox_id IN (:iids) OR conversations.assignee_id = :uid OR conversations.team_id IN (:tids)',
      iids: inbox_ids, uid: user.id, tids: team_ids
    )
  end

  def legacy_accessible_conversations
    conversations.where(inbox: user.inboxes.where(account_id: account.id))
  end

  def department_visibility_enabled?
    account.custom_attributes.is_a?(Hash) && account.custom_attributes['department_visibility_enabled'] == true
  end

  def account_user
    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
