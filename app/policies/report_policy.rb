class ReportPolicy < ApplicationPolicy
  def view?
    @account_user.administrator? || role_permission?('report_manage')
  end
end
