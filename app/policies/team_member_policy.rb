class TeamMemberPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    @account_user.administrator? || team_manage?
  end

  def destroy?
    @account_user.administrator? || team_manage?
  end

  def update?
    @account_user.administrator? || team_manage?
  end

  private

  # Fork Valcenter: custom role com 'team_manage' gerencia membros dos Times.
  def team_manage?
    @account_user.custom_role&.permissions&.include?('team_manage')
  end
end
