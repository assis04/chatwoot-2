# Fork Valcenter: sincroniza o número do WhatsApp de cada caixa Evolution
# (Channel::Api) a partir do ownerJid da instância na Evolution e grava em
# channel.additional_attributes['phone_number'] (merge — não apaga outras chaves).
#
# Por que existe: Channel::Api não tem campo de telefone; o número mora só na
# Evolution e só passa a existir DEPOIS que a instância conecta (QR lido). Um job
# agendado reconcilia periodicamente — assim caixas novas aparecem sozinhas na
# tela de Configurações e um re-pareamento (número trocado) se auto-corrige.
# Apenas leitura na Evolution (GET /instance/fetchInstances).
#
# Seguro por padrão: se EVOLUTION_API_URL / EVOLUTION_API_KEY não estiverem
# setados (staging/dev/local), o serviço é no-op. Nunca levanta pro caller —
# é cosmético e jamais pode impactar o fluxo de mensagens.
class Evolution::InstanceNumberSyncService
  include HTTParty

  FETCH_PATH = '/instance/fetchInstances'.freeze
  HTTP_TIMEOUT = 10

  def perform
    return unless configured?

    instances = fetch_instances
    return if instances.blank?

    by_name = index_by_name(instances)
    updated = 0

    Channel::Api.find_each do |channel|
      name = instance_name(channel.webhook_url)
      next if name.blank?

      instance = by_name[name]
      next if instance.blank?

      number = extract_number(instance)
      next if number.blank?

      updated += 1 if store_number(channel, number)
    end

    Rails.logger.info("[Evolution::InstanceNumberSync] atualizou #{updated} caixa(s)")
    updated
  rescue StandardError => e
    Rails.logger.error("[Evolution::InstanceNumberSync] falhou: #{e.class} #{e.message}")
    ChatwootExceptionTracker.new(e).capture_exception if defined?(ChatwootExceptionTracker)
    nil
  end

  private

  def configured?
    api_url.present? && api_key.present?
  end

  def api_url
    @api_url ||= ENV.fetch('EVOLUTION_API_URL', '').to_s.strip.chomp('/')
  end

  def api_key
    @api_key ||= ENV.fetch('EVOLUTION_API_KEY', '').to_s.strip
  end

  def fetch_instances
    response = self.class.get(
      "#{api_url}#{FETCH_PATH}",
      headers: { 'apikey' => api_key, 'Accept' => 'application/json' },
      timeout: HTTP_TIMEOUT
    )
    return [] unless response.success?

    body = response.parsed_response
    body.is_a?(Array) ? body : []
  end

  # Evolution 2.x ora devolve o objeto direto, ora embrulha em { "instance": {...} }.
  # Normaliza os dois formatos e indexa pelo nome exato da instância.
  def index_by_name(instances)
    instances.each_with_object({}) do |item, acc|
      data = item.is_a?(Hash) && item['instance'].is_a?(Hash) ? item['instance'] : item
      next unless data.is_a?(Hash)

      name = data['name'] || data['instanceName']
      acc[name] = data if name.present?
    end
  end

  # webhook_url = .../evolution/chatwoot/webhook/{InstanceName} (URL-encoded).
  # O nome da instância na Evolution ≠ nome da caixa no Chatwoot (ex: Mogi→Mogu),
  # por isso extraímos SEMPRE da URL, nunca do inbox.name.
  def instance_name(webhook_url)
    return if webhook_url.blank?

    segment = webhook_url.split('?').first.to_s.split('/').last
    return if segment.blank?

    CGI.unescape(segment)
  end

  # ownerJid "5511987654321@s.whatsapp.net" -> "+5511987654321".
  # Fallback para o campo 'number' quando o ownerJid não veio.
  def extract_number(instance)
    jid = instance['ownerJid'] || instance['owner']
    digits = jid.to_s.split('@').first.to_s.gsub(/\D/, '')
    digits = instance['number'].to_s.gsub(/\D/, '') if digits.blank?
    return if digits.blank?

    "+#{digits}"
  end

  def store_number(channel, number)
    attrs = (channel.additional_attributes || {}).dup
    return false if attrs['phone_number'] == number

    attrs['phone_number'] = number
    channel.update!(additional_attributes: attrs)
    true
  rescue StandardError => e
    Rails.logger.error("[Evolution::InstanceNumberSync] caixa #{channel.id}: #{e.message}")
    false
  end
end
