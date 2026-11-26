# Fork Valcenter: resultado da busca dentro da conversa (Messages::ConversationSearchService).
# Shape enxuto: o painel so desenha remetente, data, trecho e anexo; ao clicar, a
# mensagem completa vem pela lista normal (MessageFinder).
json.meta do
  json.total @search.total
  json.has_more @search.has_more
end

json.payload @search.messages do |message|
  json.id message.id
  json.content message.content.to_s.first(4000)
  json.created_at message.created_at.to_i
  json.message_type Message.message_types[message.message_type]
  json.private message.private
  json.sender_type message.sender_type
  json.sender_name message.sender.try(:available_name).presence || message.sender.try(:name)
  json.attachments message.attachments do |attachment|
    json.file_type attachment.file_type
    json.file_name attachment.file.attached? ? attachment.file.filename.to_s : nil
  end
end
