require 'erb'

# Fork Valcenter: client central da Evolution (WhatsApp). Concentra o acesso HTTP
# e o parsing das respostas, reusado pelo sync de números e pelo controller de
# status/QR. A chave da Evolution vive só aqui no backend (nunca vai pro front).
#
# Seguro por padrão: sem EVOLUTION_API_URL/EVOLUTION_API_KEY, `configured?` é
# false e as chamadas retornam nil. Nunca levanta pro caller (loga e devolve nil).
class Evolution::ApiClient
  include HTTParty

  TIMEOUT = 10
  CONNECT_TIMEOUT = 15

  class << self
    def configured?
      base_url.present? && api_key.present?
    end

    def base_url
      ENV.fetch('EVOLUTION_API_URL', '').to_s.strip.chomp('/')
    end

    def api_key
      ENV.fetch('EVOLUTION_API_KEY', '').to_s.strip
    end

    # webhook_url = .../evolution/chatwoot/webhook/{InstanceName} (URL-encoded).
    # O nome da instância na Evolution != nome da caixa; extrai SEMPRE do webhook.
    def instance_from_webhook(webhook_url)
      return if webhook_url.blank?

      segment = webhook_url.split('?').first.to_s.split('/').last
      return if segment.blank?

      CGI.unescape(segment)
    end

    # fetchInstances ora devolve o objeto direto, ora embrulhado em
    # { "instance": {...} }. Normaliza e indexa pelo nome exato.
    def index_by_name(instances)
      Array(instances).each_with_object({}) do |item, acc|
        data = item.is_a?(Hash) && item['instance'].is_a?(Hash) ? item['instance'] : item
        next unless data.is_a?(Hash)

        name = data['name'] || data['instanceName']
        acc[name] = data if name.present?
      end
    end

    # ownerJid "5511987654321@s.whatsapp.net" -> "+5511987654321" (fallback: number)
    def number_from_instance(instance)
      return if instance.blank?

      jid = instance['ownerJid'] || instance['owner']
      digits = jid.to_s.split('@').first.to_s.gsub(/\D/, '')
      digits = instance['number'].to_s.gsub(/\D/, '') if digits.blank?
      return if digits.blank?

      "+#{digits}"
    end

    # open (conectado) | connecting (pareando) | close (desconectado) | unknown
    def normalize_status(raw)
      case raw.to_s.downcase
      when 'open' then 'open'
      when 'connecting' then 'connecting'
      when 'close', 'closed', 'disconnected' then 'close'
      else 'unknown'
      end
    end
  end

  def fetch_instances
    body = http_get('/instance/fetchInstances')
    body.is_a?(Array) ? body : []
  end

  def connection_state(instance)
    http_get("/instance/connectionState/#{escape(instance)}")
  end

  def connect(instance)
    http_get("/instance/connect/#{escape(instance)}", timeout: CONNECT_TIMEOUT)
  end

  private

  def http_get(path, timeout: TIMEOUT)
    return nil unless self.class.configured?

    response = self.class.get(
      "#{self.class.base_url}#{path}",
      headers: { 'apikey' => self.class.api_key, 'Accept' => 'application/json' },
      timeout: timeout
    )
    return nil unless response.success?

    response.parsed_response
  rescue StandardError => e
    Rails.logger.error("[Evolution::ApiClient] GET #{path}: #{e.class} #{e.message}")
    nil
  end

  def escape(instance)
    ERB::Util.url_encode(instance.to_s)
  end
end
