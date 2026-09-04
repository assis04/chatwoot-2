class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  before_action :ensure_api_inbox, only: :update

  def index
    @messages = message_finder.perform
  end

  def create
    user = Current.user || @resource
    mb = Messages::MessageBuilder.new(user, @conversation, params)
    @message = mb.perform
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def update
    Messages::StatusUpdateService.new(message, permitted_params[:status], permitted_params[:external_error]).perform
    @message = message
  end

  def destroy
    ActiveRecord::Base.transaction do
      message.update!(content: I18n.t('conversations.messages.deleted'), content_type: :text, content_attributes: { deleted: true })
      message.attachments.destroy_all
    end
  end

  def retry
    return if message.blank?

    service = Messages::StatusUpdateService.new(message, 'sent')
    service.perform
    message.update!(content_attributes: {})
    ::SendReplyJob.perform_later(message.id)
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def translate
    return head :ok if already_translated_content_available?

    translated_content = Integrations::GoogleTranslate::ProcessorService.new(
      message: message,
      target_language: permitted_params[:target_language]
    ).perform

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations)
    end

    render json: { content: translated_content }
  rescue Google::Cloud::Error => e
    # `details` carries the clean human message; `message` includes gRPC debug noise
    render_could_not_create_error(e.details.presence || e.message)
  end

  # Fork Valcenter: edita no WhatsApp uma mensagem já enviada pelo agente, via
  # Evolution (janela de ~15 min do WhatsApp). Guarda o texto original em
  # content_attributes['edited'] e reflete o novo conteúdo no Chatwoot.
  # Autorização = acesso à conversa (BaseController já faz authorize :show?).
  def evolution_edit
    return render_evolution_error('Edição disponível apenas em caixas Evolution (API)', :unprocessable_entity) unless @conversation.inbox.api?

    msg = message
    new_content = permitted_params[:content].to_s.strip
    return render_evolution_error('Informe o novo texto', :unprocessable_entity) if new_content.blank?
    return render_evolution_error('Só mensagens enviadas pelo agente podem ser editadas', :unprocessable_entity) unless msg.outgoing?
    return render_evolution_error('Mensagem sem referência no WhatsApp', :unprocessable_entity) unless msg.source_id.to_s.start_with?('WAID:')
    return render_evolution_error('A janela de edição do WhatsApp (15 min) expirou', :unprocessable_entity) if msg.created_at < 15.minutes.ago

    number = @conversation.contact.phone_number.to_s.gsub(/\D/, '')
    number = @conversation.contact.identifier.to_s.split('@').first.to_s.gsub(/\D/, '') if number.blank?
    return render_evolution_error('Contato sem número de WhatsApp', :unprocessable_entity) if number.blank?

    instance = Evolution::ApiClient.instance_from_webhook(@conversation.inbox.channel.webhook_url)
    return render_evolution_error('Integração Evolution não configurada', :service_unavailable) if instance.blank? || !Evolution::ApiClient.configured?

    key = { remoteJid: "#{number}@s.whatsapp.net", fromMe: true, id: msg.source_id.delete_prefix('WAID:') }
    result = Evolution::ApiClient.new.update_message(instance, number, key, new_content)
    return render_evolution_error('A Evolution não confirmou a edição — tente novamente', :bad_gateway) if result.blank?

    attrs = (msg.content_attributes || {}).merge(
      'edited' => { 'original' => msg.content, 'edited_at' => Time.current.utc.iso8601, 'edited_by' => Current.user&.id }
    )
    msg.update!(content: new_content, content_attributes: attrs)
    msg.send_update_event
    @message = msg
    render json: @message.push_event_data
  end

  private

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def permitted_params
    params.permit(:id, :target_language, :status, :external_error, :content)
  end

  def render_evolution_error(message, status)
    render json: { error: message }, status: status
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end

  # API inbox check
  def ensure_api_inbox
    # Only API inboxes can update messages
    render json: { error: 'Message status update is only allowed for API inboxes' }, status: :forbidden unless @conversation.inbox.api?
  end
end
