# Fork Valcenter: reconcilia, a partir da Evolution, o número do WhatsApp e o
# status de conexão de cada caixa Evolution (Channel::Api), gravando em
# channel.additional_attributes (phone_number + connection_status; merge, não
# apaga outras chaves).
#
# Por que existe: Channel::Api não tem esses campos; ambos vivem na Evolution e
# só são conhecidos DEPOIS que a instância conecta. Um job agendado reconcilia
# periodicamente — caixas novas aparecem sozinhas na tela de Configurações, e
# desconexão/re-pareamento se auto-corrigem. Apenas leitura na Evolution.
#
# Seguro por padrão: no-op se a Evolution não está configurada. Nunca levanta.
class Evolution::InstanceNumberSyncService
  def perform
    return unless Evolution::ApiClient.configured?

    instances = client.fetch_instances
    return if instances.blank?

    by_name = Evolution::ApiClient.index_by_name(instances)
    updated = 0

    Channel::Api.find_each do |channel|
      name = Evolution::ApiClient.instance_from_webhook(channel.webhook_url)
      next if name.blank?

      instance = by_name[name]
      next if instance.blank?

      updated += 1 if sync_channel(channel, instance)
    end

    Rails.logger.info("[Evolution::InstanceNumberSync] atualizou #{updated} caixa(s)")
    updated
  rescue StandardError => e
    Rails.logger.error("[Evolution::InstanceNumberSync] falhou: #{e.class} #{e.message}")
    ChatwootExceptionTracker.new(e).capture_exception if defined?(ChatwootExceptionTracker)
    nil
  end

  private

  def client
    @client ||= Evolution::ApiClient.new
  end

  def sync_channel(channel, instance)
    number = Evolution::ApiClient.number_from_instance(instance)
    status = Evolution::ApiClient.normalize_status(instance['connectionStatus'] || instance['state'])

    attrs = (channel.additional_attributes || {}).dup
    changed = false

    if number.present? && attrs['phone_number'] != number
      attrs['phone_number'] = number
      changed = true
    end
    if status.present? && status != 'unknown' && attrs['connection_status'] != status
      attrs['connection_status'] = status
      changed = true
    end
    return false unless changed

    channel.update!(additional_attributes: attrs)
    true
  rescue StandardError => e
    Rails.logger.error("[Evolution::InstanceNumberSync] caixa #{channel.id}: #{e.message}")
    false
  end
end
