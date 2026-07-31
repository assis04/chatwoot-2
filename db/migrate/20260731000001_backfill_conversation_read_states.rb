class BackfillConversationReadStates < ActiveRecord::Migration[7.1]
  # Marca todos os agentes como "em dia" nas conversas ABERTAS existentes, para que
  # a aba "Não lidas" comece limpa: só passa a contar o que chegar APÓS o deploy.
  # Sem isso, no dia 1 cada agente veria todas as conversas como não lidas.
  def up
    now = Time.current

    Conversation.where(status: :open).find_each(batch_size: 500) do |conversation|
      member_ids = conversation.inbox.members.ids
      next if member_ids.blank?

      rows = member_ids.map do |uid|
        {
          account_id: conversation.account_id,
          conversation_id: conversation.id,
          user_id: uid,
          last_seen_at: now,
          created_at: now,
          updated_at: now
        }
      end

      ConversationReadState.upsert_all(rows, unique_by: %i[conversation_id user_id])
    end
  end

  def down
    ConversationReadState.delete_all
  end
end
