class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account)
    @conversations = conversations
    @user = user
    @account = account
  end

  def perform
    return conversations if user_role == 'administrator'

    accessible_conversations
  end

  private

  # Fork customization — department (Team) based visibility, à la Digisac.
  # When the account opts in (custom_attributes.department_visibility_enabled),
  # an agent sees conversations of the Team(s) they belong to (from any inbox/
  # number) plus the ones assigned to them. Otherwise the legacy inbox-based
  # rule is used, so the flag is a safe, reversible switch.
  def accessible_conversations
    return legacy_accessible_conversations unless department_visibility_enabled?

    team_ids = user.teams.where(account_id: account.id).pluck(:id)
    conversations.where(
      'conversations.team_id IN (:tids) OR conversations.assignee_id = :uid',
      tids: team_ids, uid: user.id
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
