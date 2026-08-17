# Fork customization — Group Management visibility.
#
# Mints a short-lived, signed token that the external Group Management app
# (embedded via the /ext iframe) uses to know which WhatsApp numbers the current
# agent may see. The app verifies the signature with the SAME shared secret
# (GROUP_CTX_SECRET), so the scope cannot be forged or widened from the browser:
# an agent only ever receives the inbox ids they belong to, and the app rejects
# any request for a number outside that set. Administrators get `is_admin: true`
# and the app then shows every number.
#
# Same visibility rule as Conversations::PermissionFilterService — kept in sync
# on purpose so groups and conversations answer to one definition of "my numbers".
class GroupManagement::ContextTokenService
  TOKEN_TTL = 8.hours

  pattr_initialize [:account!, :user!]

  def generate
    JWT.encode(payload, secret, 'HS256')
  end

  private

  def payload
    now = Time.now.to_i
    {
      account_id: account.id,
      user_id: user.id,
      is_admin: administrator?,
      # Admins see every number, so the explicit list is redundant for them.
      inbox_ids: administrator? ? [] : accessible_inbox_ids,
      iat: now,
      exp: now + TOKEN_TTL.to_i
    }
  end

  def administrator?
    account_user&.role == 'administrator'
  end

  # The inboxes the agent is a member of, within this account.
  def accessible_inbox_ids
    user.inboxes.where(account_id: account.id).pluck(:id)
  end

  def account_user
    @account_user ||= AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def secret
    ENV.fetch('GROUP_CTX_SECRET')
  end
end
