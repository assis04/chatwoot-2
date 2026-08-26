class ConversationPolicy < ApplicationPolicy
  def index?
    true
  end

  def destroy?
    administrator?
  end

  def show?
    # base (admin / bot / Digisac cross-number) gateia primeiro; se passar e o
    # usuário tiver custom role, a hierarquia de permissão de conversa refina.
    return false unless administrator? || agent_bot? || agent_can_view_conversation?
    return true unless custom_role_permissions?

    permissions = custom_role_permissions
    return true if permissions.include?('conversation_manage')
    return true if permits_unassigned_manage?(permissions)

    permits_participating?(permissions)
  end

  private

  # Fork Valcenter: custom_roles (Community) — hierarquia de visibilidade de conversa.
  def permits_unassigned_manage?(permissions)
    return false unless permissions.include?('conversation_unassigned_manage')

    unassigned_conversation? || assigned_to_user?
  end

  def permits_participating?(permissions)
    return false unless permissions.include?('conversation_participating_manage')

    assigned_to_user? || participant?
  end

  def unassigned_conversation?
    record.assignee_id.nil?
  end

  def custom_role_permissions?
    account_user&.custom_role_id.present?
  end

  def custom_role_permissions
    account_user&.custom_role&.permissions || []
  end

  def agent_can_view_conversation?
    # Fork: a conversation transferred to a person (assignee) or that the user
    # participates in is viewable/answerable even when it lives in an inbox the
    # user is not a member of — required for Digisac-style cross-number transfer.
    inbox_access? || team_access? || assigned_to_user? || participant?
  end

  def administrator?
    account_user&.administrator?
  end

  def agent_bot?
    user.is_a?(AgentBot)
  end

  def inbox_access?
    user.inboxes.where(account_id: account&.id).exists?(id: record.inbox_id)
  end

  def team_access?
    return false if record.team_id.blank?

    user.teams.where(account_id: account&.id).exists?(id: record.team_id)
  end

  def assigned_to_user?
    record.assignee_id == user.id
  end

  def participant?
    record.conversation_participants.exists?(user_id: user.id)
  end
end

ConversationPolicy.prepend_mod_with('ConversationPolicy')
