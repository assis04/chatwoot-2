class ApplicationPolicy
  attr_reader :user_context, :user, :record, :account, :account_user

  def initialize(user_context, record)
    @user_context = user_context
    @user = user_context[:user]
    @account = user_context[:account]
    @account_user = user_context[:account_user]
    @record = record
  end

  def index?
    false
  end

  def show?
    scope.exists?(id: record.id)
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def scope
    Pundit.policy_scope!(user_context, record.class)
  end

  # Fork Valcenter: custom_roles (Community). true quando o account_user tem uma
  # função personalizada que inclui a permissão dada. Usado pelas policies pra
  # conceder acesso além do administrador.
  def role_permission?(permission)
    @account_user&.custom_role&.permissions&.include?(permission)
  end

  class Scope
    attr_reader :user_context, :user, :scope, :account, :account_user

    def initialize(user_context, scope)
      @user_context = user_context
      @user = user_context[:user]
      @account = user_context[:account]
      @account_user = user_context[:account_user]
      @scope = scope
    end

    def resolve
      scope
    end
  end
end
