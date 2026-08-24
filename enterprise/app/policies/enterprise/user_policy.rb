module Enterprise::UserPolicy
  # Fork Valcenter: além do administrador, um custom role com a permissão
  # 'agent_manage' pode gerenciar AGENTES. A restrição de não poder criar/mexer
  # em ADMINISTRADORES (escalonamento de privilégio) é enforçada no
  # AgentsController (restrict_non_admin_agent_management), não aqui — a policy
  # só concede o acesso à ação; o controller limita o ESCOPO.
  def create?
    super || agent_manage?
  end

  def update?
    super || agent_manage?
  end

  def destroy?
    super || agent_manage?
  end

  def bulk_create?
    super || agent_manage?
  end

  private

  def agent_manage?
    @account_user.custom_role&.permissions&.include?('agent_manage')
  end
end
