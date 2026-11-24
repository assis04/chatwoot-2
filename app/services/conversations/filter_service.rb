class Conversations::FilterService < FilterService
  ATTRIBUTE_MODEL = 'conversation_attribute'.freeze
  # Fork Valcenter: filtro "Agente participante". O ParticipationListener grava o
  # agente como participante a cada atribuicao, e a automacao "resolver tira o dono"
  # zera o assignee_id; entao "Agente atribuido" so mostra o que o agente tem AGORA,
  # e este filtro mostra tudo que ele atendeu ou acompanha (resolvidas inclusive).
  # Fica fora do lib/filters/filter_keys.yml de proposito: aquele arquivo tambem
  # valida condicoes de automacao, que nao sabem montar este EXISTS.
  PARTICIPANT_ATTRIBUTE = 'participant_id'.freeze
  PARTICIPANT_OPERATORS = %w[equal_to not_equal_to].freeze

  def initialize(params, user, account)
    @account = account
    super(params, user)
  end

  def perform
    validate_query_operator
    @conversations = query_builder(@filters['conversations'])
    mine_count, unassigned_count, all_count, = set_count_for_all_conversations
    assigned_count = all_count - unassigned_count

    {
      conversations: conversations,
      count: {
        mine_count: mine_count,
        assigned_count: assigned_count,
        unassigned_count: unassigned_count,
        all_count: all_count
      }
    }
  end

  def build_condition_query(model_filters, query_hash, current_index)
    return participant_filter_query(query_hash, current_index) if query_hash['attribute_key'] == PARTICIPANT_ATTRIBUTE

    super
  end

  # Fork Valcenter: mesmo preload do ConversationFinder#conversations_base_query.
  # O upstream fazia includes(:messages), que carregava TODAS as mensagens de cada
  # conversa da pagina sem usar nenhuma (o partial da lista sempre consulta
  # messages.where(...) de novo), e deixava os participantes do meta em N+1.
  def base_relation
    conversations = @account.conversations.includes(
      :taggings, :inbox, :conversation_read_states, { assignee: { avatar_attachment: [:blob] } },
      { contact: { avatar_attachment: [:blob] } }, :team, :contact_inbox,
      { conversation_participants: { user: { avatar_attachment: [:blob] } } }
    )

    Conversations::PermissionFilterService.new(
      conversations,
      @user,
      @account
    ).perform
  end

  def current_page
    @params[:page] || 1
  end

  def filter_config
    {
      entity: 'Conversation',
      table_name: 'conversations'
    }
  end

  def conversations
    @conversations.sort_on_last_activity_at.page(current_page)
  end

  private

  def participant_filter_query(query_hash, current_index)
    operator = query_hash[:filter_operator]
    unless PARTICIPANT_OPERATORS.include?(operator)
      raise CustomExceptions::CustomFilter::InvalidOperator.new(attribute_name: PARTICIPANT_ATTRIBUTE,
                                                                allowed_keys: PARTICIPANT_OPERATORS)
    end

    user_ids = Array.wrap(query_hash['values']).filter_map { |value| Integer(value.to_s, exception: false) }
    raise CustomExceptions::CustomFilter::InvalidValue.new(attribute_name: PARTICIPANT_ATTRIBUTE) if user_ids.empty?

    @filter_values["value_#{current_index}"] = user_ids
    exists = 'EXISTS (SELECT 1 FROM conversation_participants ' \
             'WHERE conversation_participants.conversation_id = conversations.id ' \
             "AND conversation_participants.user_id IN (:value_#{current_index}))"
    "#{'NOT ' if operator == 'not_equal_to'}#{exists} #{query_hash[:query_operator]}"
  end
end
