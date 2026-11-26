# Fork Valcenter: busca dentro de UMA conversa (lupa no cabecalho da conversa).
#
# A lista de mensagens do front so carrega 20 por vez, entao a busca e no servidor
# para cobrir a conversa inteira. Casa o texto da mensagem (inclusive notas privadas)
# e o nome dos arquivos anexados; ignora mensagens de atividade ("conversa resolvida
# por ..."), que so poluiriam o resultado.
#
# Sem diferenciar maiusculas nem acentos: agente digita "orcamento" e acha
# "Orçamento". Feito com translate() em vez da extensao unaccent para nao depender
# de migration/superusuario; o escopo e uma conversa (indice por conversation_id),
# entao varrer as linhas dela e barato.
class Messages::ConversationSearchService
  PER_PAGE = 30
  MIN_TERM_LENGTH = 2
  MAX_TERM_LENGTH = 200
  ACCENTED = 'áàâãäåéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÅÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ'.freeze
  PLAIN    = 'aaaaaaeeeeiiiiooooouuuucnaaaaaaeeeeiiiiooooouuuucn'.freeze

  Result = Struct.new(:messages, :total, :has_more, keyword_init: true)

  def initialize(conversation, term, page: 1)
    @conversation = conversation
    @term = term.to_s.strip.first(MAX_TERM_LENGTH)
    @page = [page.to_i, 1].max
  end

  def perform
    return Result.new(messages: [], total: 0, has_more: false) if @term.length < MIN_TERM_LENGTH

    scope = matching_messages
    total = scope.count
    messages = scope.includes(:sender, attachments: { file_attachment: :blob })
                    .reorder(created_at: :desc, id: :desc)
                    .offset((@page - 1) * PER_PAGE)
                    .limit(PER_PAGE)
                    .to_a

    Result.new(messages: messages, total: total, has_more: @page * PER_PAGE < total)
  end

  private

  def matching_messages
    base = @conversation.messages.where.not(message_type: :activity)
    base.where(folded_like('messages.content'), folded_binds)
        .or(base.where(id: messages_with_matching_file))
  end

  def messages_with_matching_file
    Attachment.joins(file_attachment: :blob)
              .where(message_id: @conversation.messages.select(:id))
              .where(folded_like('active_storage_blobs.filename'), folded_binds)
              .select(:message_id)
  end

  def folded_like(column)
    "translate(lower(#{column}), :accented, :plain) LIKE :pattern"
  end

  def folded_binds
    @folded_binds ||= {
      accented: ACCENTED,
      plain: PLAIN,
      pattern: "%#{ActiveRecord::Base.sanitize_sql_like(@term.downcase.tr(ACCENTED, PLAIN))}%"
    }
  end
end
