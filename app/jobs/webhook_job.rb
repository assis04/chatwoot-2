class WebhookJob < ApplicationJob
  queue_as :medium

  # Fork Valcenter (hardening/LGPD): os argumentos deste job carregam o payload
  # completo do webhook (conteudo da mensagem + PII do contato: nome, telefone,
  # identifier), o `secret` do HMAC e a URL com `key`. O log padrao do ActiveJob
  # ("Enqueued/Performing ... with arguments: ...") despejava tudo isso em texto
  # puro no Sidekiq a cada entrega. Desligar o log de argumentos SO deste job
  # remove essa exposicao sem afetar o resto.
  self.log_arguments = false

  #  There are 3 types of webhooks, account, inbox and agent_bot
  def perform(url, payload, webhook_type = :account_webhook, secret: nil, delivery_id: nil)
    Webhooks::Trigger.execute(url, payload, webhook_type, secret: secret, delivery_id: delivery_id)
  end
end
