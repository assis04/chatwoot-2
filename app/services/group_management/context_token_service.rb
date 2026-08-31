# Fork customization — Group Management visibility.
#
# Mints a short-lived, signed token that the external Group Management app
# (embedded via the /ext iframe) uses to know which WhatsApp numbers the current
# agent may see. The app verifies the signature with the SAME shared secret
# (GROUP_CTX_SECRET), so the scope cannot be forged or widened from the browser:
# an agent only ever receives the inbox ids they belong to, and the app rejects
# any request for a number outside that set. Administrators get `is_admin: true`
# AND the explicit list of every inbox IN THIS ACCOUNT — the scope is always
# bounded by the account, never global, so one account can't see another's
# numbers/groups (multi-tenant isolation).
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
      # SEMPRE uma lista explícita e escopada A ESTA conta — inclusive pra admin
      # (todas as caixas da conta). Antes o admin recebia [] e o app externo lia
      # isso como "todos os números globalmente", vazando grupos de OUTRAS contas
      # (ex.: uma conta nova enxergando os números da conta 1). Com a lista sempre
      # presente e limitada à conta, o token nunca concede escopo além dela.
      inbox_ids: scoped_inbox_ids,
      iat: now,
      exp: now + TOKEN_TTL.to_i
    }
  end

  def administrator?
    account_user&.role == 'administrator'
  end

  # Caixas visíveis DENTRO desta conta: admin vê todas as da conta; agente vê só
  # as que participa. Nunca cruza a fronteira da conta.
  def scoped_inbox_ids
    scope = administrator? ? account.inboxes : user.inboxes.where(account_id: account.id)
    scope.pluck(:id)
  end

  def account_user
    @account_user ||= AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def secret
    ENV.fetch('GROUP_CTX_SECRET')
  end
end
