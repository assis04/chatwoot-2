class InboxPolicy < ApplicationPolicy
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
      # ATENÇÃO: este scope alimenta O ÚNICO endpoint GET /inboxes, que popula o
      # store `inboxes` usado no MENU/sidebar e nas conversas — não só nas
      # Configurações. Ampliar aqui vaza o nome de todas as caixas pro menu do
      # agente. Por isso a visibilidade da LISTA é sempre "as minhas"
      # (assigned_inboxes); um gestor inbox_manage ainda pode ABRIR/gerenciar uma
      # caixa específica via InboxPolicy#show?/update?/manage_members?.
      user.assigned_inboxes
    end
  end

  def index?
    true
  end

  def show?
    # FIXME: for agent bots, lets bring this validation to policies as well in future
    return true if @user.is_a?(AgentBot)

    Current.user.assigned_inboxes.include?(record) || inbox_manage?
  end

  def assignable_agents?
    true
  end

  def agent_bot?
    true
  end

  def campaigns?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator? || inbox_manage?
  end

  def destroy?
    @account_user.administrator?
  end

  # Fork Valcenter: gerenciar colaboradores (agentes) da caixa — alvo usado pelo
  # InboxMembersController. Liberado pra admin e pra quem tem 'inbox_manage'. É
  # separado de create?/destroy? (que criam/apagam a CAIXA e seguem só-admin).
  def manage_members?
    @account_user.administrator? || inbox_manage?
  end

  def set_agent_bot?
    @account_user.administrator?
  end

  def avatar?
    @account_user.administrator?
  end

  def sync_templates?
    @account_user.administrator?
  end

  def health?
    @account_user.administrator?
  end

  def reset_secret?
    @account_user.administrator?
  end

  def enable_whatsapp_calling?
    @account_user.administrator?
  end

  def disable_whatsapp_calling?
    @account_user.administrator?
  end

  def set_inbound_calls?
    @account_user.administrator?
  end

  private

  def inbox_manage?
    @account_user.custom_role&.permissions&.include?('inbox_manage')
  end
end
