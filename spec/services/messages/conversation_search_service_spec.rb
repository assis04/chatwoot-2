require 'rails_helper'

RSpec.describe Messages::ConversationSearchService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:other_conversation) { create(:conversation, account: account, inbox: conversation.inbox) }

  def add_message(content, **attrs)
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox, content: content, **attrs)
  end

  def search(term, page: 1)
    described_class.new(conversation, term, page: page).perform
  end

  it 'finds messages ignoring case and accents, newest first' do
    older = add_message('Segue o Orçamento da cozinha', created_at: 2.days.ago)
    newer = add_message('orcamento atualizado', created_at: 1.day.ago)
    add_message('nada a ver')

    result = search('ORCAMENTO')

    expect(result.messages.map(&:id)).to eq([newer.id, older.id])
    expect(result.total).to eq(2)
    expect(result.has_more).to be(false)
  end

  it 'matches an accented term against plain text too' do
    message = add_message('nao consigo abrir')

    expect(search('não').messages).to contain_exactly(message)
  end

  it 'includes private notes but skips activity messages' do
    note = add_message('cliente pediu desconto', private: true)
    add_message('Conversa resolvida por desconto', message_type: :activity)

    expect(search('desconto').messages).to contain_exactly(note)
  end

  it 'finds a message by the name of its attachment' do
    message = add_message('segue', message_type: :outgoing)
    attachment = message.attachments.create!(account_id: account.id, file_type: :file)
    attachment.file.attach(io: StringIO.new('pdf'), filename: 'Orçamento Sala.pdf', content_type: 'application/pdf')

    expect(search('orcamento sala').messages).to contain_exactly(message)
  end

  it 'never returns messages from another conversation' do
    create(:message, account: account, conversation: other_conversation, inbox: other_conversation.inbox, content: 'orcamento')

    expect(search('orcamento').messages).to be_empty
  end

  it 'treats LIKE wildcards as plain characters' do
    add_message('qualquer coisa')
    literal = add_message('desconto de 10%')

    expect(search('0%').messages).to contain_exactly(literal)
    # sem escapar, '%%' e '_ _' casariam com 'qualquer coisa'
    expect(search('%%').messages).to be_empty
    expect(search('_ _').messages).to be_empty
  end

  it 'ignores terms shorter than two characters' do
    add_message('a')

    result = search(' a ')

    expect(result.messages).to be_empty
    expect(result.total).to eq(0)
  end

  it 'paginates and reports whether there is more' do
    (described_class::PER_PAGE + 2).times { |index| add_message("item #{index}", created_at: index.minutes.ago) }

    first_page = search('item')
    second_page = search('item', page: 2)

    expect(first_page.messages.size).to eq(described_class::PER_PAGE)
    expect(first_page.has_more).to be(true)
    expect(second_page.messages.size).to eq(2)
    expect(second_page.has_more).to be(false)
    expect(first_page.messages & second_page.messages).to be_empty
  end
end
