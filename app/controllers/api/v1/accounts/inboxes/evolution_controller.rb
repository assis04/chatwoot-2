# Fork Valcenter: proxy seguro pro status de conexão + QR da Evolution. A chave
# da Evolution fica no backend; o front só fala com o Chatwoot autenticado.
# Autorização: admin OU quem tem 'inbox_manage' (mesmo teto de gerir a caixa).
class Api::V1::Accounts::Inboxes::EvolutionController < Api::V1::Accounts::BaseController
  before_action :ensure_configured
  before_action :authorize_evolution!
  before_action :fetch_inbox, only: [:status, :connect]

  # GET /api/v1/accounts/:account_id/inboxes/evolution/statuses
  # Status ao vivo de TODAS as caixas Evolution da conta em 1 chamada.
  def statuses
    by_name = Evolution::ApiClient.index_by_name(client.fetch_instances)

    result = api_inboxes.each_with_object({}) do |inbox, acc|
      name = Evolution::ApiClient.instance_from_webhook(inbox.channel.webhook_url)
      instance = name ? by_name[name] : nil
      raw = instance && (instance['connectionStatus'] || instance['state'])
      acc[inbox.id] = Evolution::ApiClient.normalize_status(raw)
    end

    render json: { statuses: result }
  end

  # GET .../inboxes/:id/evolution/status  — status ao vivo de uma caixa.
  def status
    render json: { status: state_of(client.connection_state(@instance_name)) }
  end

  # POST .../inboxes/:id/evolution/connect — inicia o pareamento e devolve o QR.
  # Se já estiver conectada, devolve o status (sem QR).
  def connect
    result = client.connect(@instance_name)

    if result.is_a?(Hash) && result['base64'].present?
      render json: {
        status: 'qrcode',
        qrcode: result['base64'],
        code: result['code'],
        pairing_code: result['pairingCode']
      }
    else
      render json: { status: state_of(result) }
    end
  end

  private

  def client
    @client ||= Evolution::ApiClient.new
  end

  def api_inboxes
    Current.account.inboxes.where(channel_type: 'Channel::Api').includes(:channel)
  end

  def state_of(payload)
    raw = payload.is_a?(Hash) ? (payload.dig('instance', 'state') || payload['state']) : nil
    Evolution::ApiClient.normalize_status(raw)
  end

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:id])

    return render_error('Não é uma caixa Evolution', :unprocessable_entity) unless @inbox.channel_type == 'Channel::Api'

    @instance_name = Evolution::ApiClient.instance_from_webhook(@inbox.channel.webhook_url)
    render_error('Caixa sem instância Evolution', :unprocessable_entity) if @instance_name.blank?
  end

  def authorize_evolution!
    account_user = Current.account_user
    return if account_user&.administrator?
    return if account_user&.custom_role&.permissions&.include?('inbox_manage')

    raise Pundit::NotAuthorizedError
  end

  def ensure_configured
    return if Evolution::ApiClient.configured?

    render_error('Integração Evolution não configurada', :service_unavailable)
  end

  def render_error(message, status)
    render json: { error: message }, status: status
  end
end
