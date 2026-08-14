# Fork customization — shared contact-visibility scoping (Digisac-style isolation).
# Any controller that reads contacts must scope them the same way as the main
# ContactsController, otherwise an agent could reach contacts of another number
# (IDOR) via a secondary endpoint (contact sub-resources, companies, merges).
# Admins bypass the scope; non-admin agents are restricted to contacts owned by
# / linked to their inboxes (Contact#visible_to_inboxes).
module ContactVisibilityScopable
  extend ActiveSupport::Concern

  private

  def contact_visibility_scope(relation)
    return relation if contact_scope_administrator?

    relation.visible_to_inboxes(agent_visible_inbox_ids)
  end

  def contact_scope_administrator?
    account_user = ::AccountUser.find_by(account_id: Current.account.id, user_id: Current.user.id)
    account_user.nil? || account_user.administrator?
  end

  def agent_visible_inbox_ids
    @agent_visible_inbox_ids ||= Current.user.inboxes.where(account_id: Current.account.id).pluck(:id)
  end
end
