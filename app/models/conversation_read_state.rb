# == Schema Information
#
# Table name: conversation_read_states
#
#  id              :bigint           not null, primary key
#  last_seen_at    :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  conversation_id :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_conv_read_states_on_conversation_and_user       (conversation_id,user_id) UNIQUE
#  index_conversation_read_states_on_account_id          (account_id)
#  index_conversation_read_states_on_conversation_id     (conversation_id)
#  index_conversation_read_states_on_user_id             (user_id)
#

# Rastreia, POR AGENTE, quando cada usuário viu cada conversa pela última vez.
# É a base do "não lido por agente" — independente do agent_last_seen_at compartilhado
# na conversa (que zera pra todos quando qualquer um abre).
class ConversationReadState < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :user

  validates :conversation_id, uniqueness: { scope: :user_id }
end
