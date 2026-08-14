class Api::V1::Accounts::Contacts::BaseController < Api::V1::Accounts::BaseController
  include ContactVisibilityScopable

  before_action :ensure_contact

  private

  def ensure_contact
    # Scoped so an agent cannot reach a contact (and its notes/conversations/
    # attachments) outside their inbox visibility via a guessed contact_id.
    @contact = contact_visibility_scope(Current.account.contacts).find(params[:contact_id])
  end
end
