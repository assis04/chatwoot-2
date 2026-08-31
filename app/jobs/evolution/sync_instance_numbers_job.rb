# Fork Valcenter: dispara a reconciliação dos números de WhatsApp das caixas
# Evolution. Agendado em config/schedule.yml (a cada 30 min). No-op quando a
# Evolution não está configurada (EVOLUTION_API_URL / EVOLUTION_API_KEY).
class Evolution::SyncInstanceNumbersJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Evolution::InstanceNumberSyncService.new.perform
  end
end
