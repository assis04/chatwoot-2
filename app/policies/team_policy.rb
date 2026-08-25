class TeamPolicy < ApplicationPolicy
  def index?
    true
  end

  def update?
    @account_user.administrator? || team_manage?
  end

  def show?
    true
  end

  def create?
    @account_user.administrator? || team_manage?
  end

  def destroy?
    @account_user.administrator? || team_manage?
  end

  private

  # Fork Valcenter: custom role com 'team_manage' gerencia Times por completo.
  def team_manage?
    @account_user.custom_role&.permissions&.include?('team_manage')
  end
end
