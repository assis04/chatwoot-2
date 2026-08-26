class CustomRolePolicy < ApplicationPolicy
  # Fork Valcenter: quem tem 'agent_manage' pode LISTAR/VER as funções (só leitura),
  # pra conseguir atribuí-las ao cadastrar agentes. Criar/editar/apagar função
  # continua exclusivo de administrador.
  def index?
    @account_user.administrator? || role_permission?('agent_manage')
  end

  def show?
    @account_user.administrator? || role_permission?('agent_manage')
  end

  def update?
    @account_user.administrator?
  end

  def create?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end
end
