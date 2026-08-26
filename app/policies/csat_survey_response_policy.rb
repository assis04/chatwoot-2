class CsatSurveyResponsePolicy < ApplicationPolicy
  def index?
    @account_user.administrator? || role_permission?('report_manage')
  end

  def metrics?
    @account_user.administrator? || role_permission?('report_manage')
  end

  def download?
    @account_user.administrator? || role_permission?('report_manage')
  end

  def update?
    @account_user.administrator? || role_permission?('report_manage')
  end
end

CsatSurveyResponsePolicy.prepend_mod_with('CsatSurveyResponsePolicy')
