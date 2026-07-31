class CreateConversationReadStates < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_read_states do |t|
      t.references :account, null: false
      t.references :conversation, null: false
      t.references :user, null: false
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :conversation_read_states, %i[conversation_id user_id], unique: true,
                                                                      name: 'index_conv_read_states_on_conversation_and_user'
  end
end
