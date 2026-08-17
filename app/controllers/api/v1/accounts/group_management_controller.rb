class Api::V1::Accounts::GroupManagementController < Api::V1::Accounts::BaseController
  # Issues the signed context token consumed by the external Group Management
  # app. Authenticated as any agent of the account (BaseController); the token
  # is scoped to the caller (their own inbox ids), so there is nothing extra to
  # authorize here — an agent cannot request a scope wider than their own.
  def context_token
    token = GroupManagement::ContextTokenService.new(
      account: Current.account,
      user: Current.user
    ).generate

    render json: { token: token }
  end
end
