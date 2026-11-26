import { flushPromises, mount } from '@vue/test-utils';
import { ref } from 'vue';
import ConversationSearchPanel from '../ConversationSearchPanel.vue';
import { useConversationSearch } from 'dashboard/composables/useConversationSearch';

const { dispatch, search, useAlert } = vi.hoisted(() => ({
  dispatch: vi.fn(),
  search: vi.fn(),
  useAlert: vi.fn(),
}));

vi.mock('vuex', () => ({ useStore: () => ({ dispatch }) }));
vi.mock('dashboard/composables', () => ({ useAlert }));
vi.mock('dashboard/api/inbox/message', () => ({ default: { search } }));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key, locale: ref('pt_BR') }),
}));

const ButtonStub = {
  props: ['label'],
  emits: ['click'],
  template:
    '<button type="button" @click="$emit(\'click\')">{{ label }}</button>',
};

const result = (id, content, extra = {}) => ({
  id,
  content,
  created_at: 1764000000,
  message_type: 0,
  private: false,
  sender_type: 'Contact',
  sender_name: 'Ana',
  attachments: [],
  ...extra,
});

const mountPanel = () =>
  mount(ConversationSearchPanel, {
    props: { currentChat: { id: 7 } },
    attachTo: document.body,
    global: {
      stubs: { Button: ButtonStub, Spinner: true },
    },
  });

const typeTerm = async (wrapper, value) => {
  await wrapper.find('input').setValue(value);
  vi.advanceTimersByTime(300);
  await flushPromises();
};

describe('ConversationSearchPanel', () => {
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout'] });
    vi.clearAllMocks();
    search.mockResolvedValue({
      data: {
        meta: { total: 1, has_more: false },
        payload: [result(11, 'Segue o Orçamento da sala')],
      },
    });
    useConversationSearch().open();
  });

  afterEach(() => {
    vi.useRealTimers();
    document.body.innerHTML = '';
  });

  it('searches the server after the user stops typing and highlights the match', async () => {
    const wrapper = mountPanel();
    await typeTerm(wrapper, 'orcamento');

    expect(search).toHaveBeenCalledTimes(1);
    expect(search.mock.calls[0][0]).toEqual({
      conversationId: 7,
      q: 'orcamento',
      page: 1,
    });
    expect(search.mock.calls[0][1].signal).toBeInstanceOf(AbortSignal);
    expect(wrapper.find('[role="status"]').text()).toBe(
      'CONVERSATION.SEARCH_IN_CONVERSATION.RESULTS'
    );
    expect(wrapper.find('mark').text()).toBe('Orçamento');
    wrapper.unmount();
  });

  it('does not search with fewer than two characters', async () => {
    const wrapper = mountPanel();
    await typeTerm(wrapper, ' o ');

    expect(search).not.toHaveBeenCalled();
    expect(wrapper.find('[role="status"]').text()).toBe(
      'CONVERSATION.SEARCH_IN_CONVERSATION.HINT'
    );
    wrapper.unmount();
  });

  it('loads the history up to the message, centers it and highlights it', async () => {
    const target = document.createElement('div');
    target.id = 'message11';
    target.scrollIntoView = vi.fn();
    document.body.appendChild(target);
    dispatch.mockResolvedValue(true);

    const wrapper = mountPanel();
    await typeTerm(wrapper, 'orcamento');
    await wrapper.find('[data-result-index="0"] button').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('loadMessagesUntil', {
      conversationId: 7,
      messageId: 11,
    });
    expect(target.scrollIntoView).toHaveBeenCalledWith({ block: 'center' });
    expect(target.classList.contains('!bg-n-amber-3')).toBe(true);

    vi.advanceTimersByTime(1800);
    expect(target.classList.contains('!bg-n-amber-3')).toBe(false);
    wrapper.unmount();
  });

  it('tells the agent when the message cannot be opened', async () => {
    dispatch.mockResolvedValue(false);
    const wrapper = mountPanel();
    await typeTerm(wrapper, 'orcamento');
    await wrapper.find('input').trigger('keydown', { key: 'Enter' });
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith(
      'CONVERSATION.SEARCH_IN_CONVERSATION.JUMP_ERROR'
    );
    wrapper.unmount();
  });

  it('shows the error state when the search request fails', async () => {
    search.mockRejectedValueOnce(new Error('boom'));
    const wrapper = mountPanel();
    await typeTerm(wrapper, 'orcamento');

    expect(wrapper.find('[role="status"]').text()).toBe(
      'CONVERSATION.SEARCH_IN_CONVERSATION.ERROR'
    );
    wrapper.unmount();
  });

  it('closes with Escape', async () => {
    const { isOpen } = useConversationSearch();
    const wrapper = mountPanel();
    await wrapper.find('input').trigger('keydown', { key: 'Escape' });

    expect(isOpen.value).toBe(false);
    wrapper.unmount();
  });
});
