<script setup>
// Fork Valcenter: busca dentro da conversa. Painel lateral (no lugar do painel do
// contato, como o WhatsApp Web) que busca no SERVIDOR — a tela so tem 20
// mensagens carregadas por vez — e, ao clicar num resultado, carrega o historico
// ate a mensagem, centraliza e destaca.
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useWindowSize } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import HighlightedText from './HighlightedText';
import MessageApi from 'dashboard/api/inbox/message';
import { useConversationSearch } from 'dashboard/composables/useConversationSearch';
import { buildSnippet, findMatches } from 'dashboard/helper/messageSearch';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  currentChat: { type: Object, required: true },
});

const MIN_TERM_LENGTH = 2;
const DEBOUNCE_MS = 300;
const HIGHLIGHT_MS = 1800;
const LOAD_MORE_OFFSET_PX = 80;
const HIGHLIGHT_CLASSES = ['!bg-n-amber-3', 'rounded-lg'];
const ELLIPSIS = { text: '…', match: false };

// Trecho cortado no meio do texto ganha reticencias nas pontas.
const snippetSegments = (text, query) => {
  const { segments, truncatedStart, truncatedEnd } = buildSnippet(text, query);
  if (!segments.length) return segments;
  return [
    ...(truncatedStart ? [ELLIPSIS] : []),
    ...segments,
    ...(truncatedEnd ? [ELLIPSIS] : []),
  ];
};

const { t, locale } = useI18n();
const store = useStore();
const { width: windowWidth } = useWindowSize();
const { close, focusRequest } = useConversationSearch();

const inputRef = ref(null);
const listRef = ref(null);
const term = ref('');
const searchedTerm = ref('');
const results = ref([]);
const total = ref(0);
const hasMore = ref(false);
const page = ref(1);
const isLoading = ref(false);
const hasError = ref(false);
const activeIndex = ref(-1);
const jumpingId = ref(null);

let debounceTimer = null;
let controller = null;
let highlightTimer = null;
let highlightedElement = null;

const trimmedTerm = computed(() => term.value.trim());
const isSmallScreen = computed(
  () => windowWidth.value < wootConstants.SMALL_SCREEN_BREAKPOINT
);

const dateFormatter = computed(() => {
  const options = {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  };
  try {
    return new Intl.DateTimeFormat(
      String(locale.value || '').replace('_', '-'),
      options
    );
  } catch (error) {
    return new Intl.DateTimeFormat(undefined, options);
  }
});

const senderLabel = result => {
  if (result.sender_name) return result.sender_name;
  return result.message_type === MESSAGE_TYPE.INCOMING
    ? t('CONVERSATION.SEARCH_IN_CONVERSATION.CONTACT_FALLBACK')
    : t('CONVERSATION.SEARCH_IN_CONVERSATION.TEAM_FALLBACK');
};

// Mostra o nome do arquivo quando foi ele que casou, ou quando a mensagem nao
// tem texto (so o anexo).
const matchedFiles = result => {
  const names = (result.attachments || [])
    .map(attachment => attachment.file_name)
    .filter(Boolean);
  const hasText = Boolean(String(result.content || '').trim());
  return names
    .filter(
      name => !hasText || findMatches(name, searchedTerm.value).length > 0
    )
    .map((name, index) => ({
      key: `${index}-${name}`,
      segments: snippetSegments(name, searchedTerm.value),
    }));
};

const decoratedResults = computed(() =>
  results.value.map(result => ({
    ...result,
    senderLabel: senderLabel(result),
    dateLabel: dateFormatter.value.format(new Date(result.created_at * 1000)),
    segments: snippetSegments(result.content, searchedTerm.value),
    files: matchedFiles(result),
  }))
);

const isSearchingNewTerm = computed(
  () => isLoading.value && searchedTerm.value !== trimmedTerm.value
);

const statusText = computed(() => {
  if (trimmedTerm.value.length < MIN_TERM_LENGTH) {
    return t('CONVERSATION.SEARCH_IN_CONVERSATION.HINT');
  }
  if (hasError.value) return t('CONVERSATION.SEARCH_IN_CONVERSATION.ERROR');
  if (isSearchingNewTerm.value) {
    return t('CONVERSATION.SEARCH_IN_CONVERSATION.SEARCHING');
  }
  if (!total.value) return t('CONVERSATION.SEARCH_IN_CONVERSATION.EMPTY');
  return t('CONVERSATION.SEARCH_IN_CONVERSATION.RESULTS', total.value);
});

const resetResults = () => {
  results.value = [];
  total.value = 0;
  hasMore.value = false;
  page.value = 1;
  activeIndex.value = -1;
  hasError.value = false;
};

const runSearch = async (query, nextPage = 1) => {
  controller?.abort();
  if (query.length < MIN_TERM_LENGTH) {
    controller = null;
    isLoading.value = false;
    searchedTerm.value = '';
    resetResults();
    return;
  }

  const requestController = new AbortController();
  controller = requestController;
  isLoading.value = true;
  hasError.value = false;
  try {
    const { data } = await MessageApi.search(
      { conversationId: props.currentChat.id, q: query, page: nextPage },
      { signal: requestController.signal }
    );
    if (controller !== requestController) return;

    results.value =
      nextPage === 1 ? data.payload : [...results.value, ...data.payload];
    total.value = data.meta.total;
    hasMore.value = data.meta.has_more;
    page.value = nextPage;
    searchedTerm.value = query;
    if (nextPage === 1) activeIndex.value = data.payload.length ? 0 : -1;
  } catch (error) {
    if (!requestController.signal.aborted) hasError.value = true;
  } finally {
    if (controller === requestController) {
      controller = null;
      isLoading.value = false;
    }
  }
};

const loadMore = () => {
  if (hasMore.value && !isLoading.value) {
    runSearch(searchedTerm.value, page.value + 1);
  }
};

const onListScroll = () => {
  const list = listRef.value;
  if (!list) return;
  if (
    list.scrollTop + list.clientHeight >=
    list.scrollHeight - LOAD_MORE_OFFSET_PX
  ) {
    loadMore();
  }
};

const waitForMessageElement = async messageId => {
  for (let frame = 0; frame < 20; frame += 1) {
    const element = document.getElementById(`message${messageId}`);
    if (element) return element;
    // eslint-disable-next-line no-await-in-loop
    await new Promise(resolve => {
      requestAnimationFrame(resolve);
    });
  }
  return null;
};

const clearHighlight = () => {
  clearTimeout(highlightTimer);
  highlightedElement?.classList.remove(...HIGHLIGHT_CLASSES);
  highlightedElement = null;
};

const highlight = element => {
  clearHighlight();
  element.classList.add(
    'transition-colors',
    'duration-700',
    ...HIGHLIGHT_CLASSES
  );
  highlightedElement = element;
  highlightTimer = setTimeout(clearHighlight, HIGHLIGHT_MS);
};

const jumpTo = async (result, index) => {
  if (jumpingId.value) return;
  activeIndex.value = index;
  jumpingId.value = result.id;
  try {
    const found = await store.dispatch('loadMessagesUntil', {
      conversationId: props.currentChat.id,
      messageId: result.id,
    });
    const element = found ? await waitForMessageElement(result.id) : null;
    if (!element) {
      useAlert(t('CONVERSATION.SEARCH_IN_CONVERSATION.JUMP_ERROR'));
      return;
    }
    // Sem scroll suave: o MessagesView carrega mensagens antigas ao chegar perto
    // do topo e reposiciona a tela, o que interromperia uma animacao no meio.
    element.scrollIntoView({ block: 'center' });
    highlight(element);
    if (isSmallScreen.value) close();
  } catch (error) {
    useAlert(t('CONVERSATION.SEARCH_IN_CONVERSATION.JUMP_ERROR'));
  } finally {
    jumpingId.value = null;
  }
};

const scrollActiveIntoView = () => {
  nextTick(() => {
    listRef.value
      ?.querySelector(`[data-result-index="${activeIndex.value}"]`)
      ?.scrollIntoView({ block: 'nearest' });
  });
};

const moveActive = step => {
  if (!results.value.length) return;
  const last = results.value.length - 1;
  activeIndex.value = Math.min(Math.max(activeIndex.value + step, 0), last);
  scrollActiveIntoView();
  if (activeIndex.value >= last - 2) loadMore();
};

const onInputKeydown = event => {
  if (event.key === 'ArrowDown') {
    event.preventDefault();
    moveActive(1);
  } else if (event.key === 'ArrowUp') {
    event.preventDefault();
    moveActive(-1);
  } else if (event.key === 'Enter') {
    event.preventDefault();
    const index = Math.max(activeIndex.value, 0);
    if (results.value[index]) jumpTo(results.value[index], index);
  } else if (event.key === 'Escape') {
    event.preventDefault();
    close();
  }
};

const focusInput = () => {
  nextTick(() => {
    inputRef.value?.focus();
    inputRef.value?.select();
  });
};

const clearTerm = () => {
  term.value = '';
  focusInput();
};

watch(term, () => {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => runSearch(trimmedTerm.value), DEBOUNCE_MS);
});

// Trocou de conversa: a busca era da anterior.
watch(
  () => props.currentChat.id,
  () => close()
);

watch(focusRequest, focusInput);

onMounted(focusInput);

onBeforeUnmount(() => {
  clearTimeout(debounceTimer);
  controller?.abort();
});
</script>

<template>
  <aside
    class="bg-n-surface-2 h-full overflow-hidden flex flex-col fixed top-0 z-40 w-full max-w-sm ltr:right-0 rtl:left-0 md:static md:w-[320px] md:min-w-[320px] ltr:border-l rtl:border-r border-n-weak 2xl:min-w-[360px] 2xl:w-[360px] shadow-lg md:shadow-none"
    :aria-label="t('CONVERSATION.SEARCH_IN_CONVERSATION.TITLE')"
  >
    <header
      class="flex items-center gap-2 h-12 px-4 border-b border-n-weak shrink-0"
    >
      <h2
        class="flex-1 min-w-0 m-0 text-sm font-medium truncate text-n-slate-12"
      >
        {{ t('CONVERSATION.SEARCH_IN_CONVERSATION.TITLE') }}
      </h2>
      <Button
        v-tooltip.bottom="t('CONVERSATION.SEARCH_IN_CONVERSATION.CLOSE')"
        size="xs"
        variant="ghost"
        color="slate"
        icon="i-lucide-x"
        :aria-label="t('CONVERSATION.SEARCH_IN_CONVERSATION.CLOSE')"
        @click="close"
      />
    </header>

    <div class="px-4 pt-3 pb-2 shrink-0">
      <div
        class="flex items-center gap-2 h-9 px-3 rounded-lg bg-n-alpha-black2 outline outline-1 -outline-offset-1 outline-n-weak focus-within:outline-n-brand"
      >
        <span
          class="i-lucide-search size-4 shrink-0 text-n-slate-10"
          aria-hidden="true"
        />
        <input
          ref="inputRef"
          v-model="term"
          type="text"
          autocomplete="off"
          spellcheck="false"
          class="flex-1 min-w-0 h-full p-0 m-0 text-sm bg-transparent border-0 shadow-none outline-none text-n-slate-12 placeholder:text-n-slate-10"
          :placeholder="t('CONVERSATION.SEARCH_IN_CONVERSATION.PLACEHOLDER')"
          :aria-label="t('CONVERSATION.SEARCH_IN_CONVERSATION.PLACEHOLDER')"
          @keydown="onInputKeydown"
        />
        <Spinner v-if="isLoading" :size="14" class="shrink-0 text-n-slate-10" />
        <button
          v-else-if="term"
          type="button"
          class="flex items-center justify-center rounded size-5 shrink-0 text-n-slate-10 hover:text-n-slate-12"
          :aria-label="t('CONVERSATION.SEARCH_IN_CONVERSATION.CLEAR')"
          @click="clearTerm"
        >
          <span class="i-lucide-x size-3.5" aria-hidden="true" />
        </button>
      </div>
      <p class="mt-2 mb-0 text-xs text-n-slate-11" role="status">
        {{ statusText }}
      </p>
    </div>

    <ul
      v-if="decoratedResults.length"
      ref="listRef"
      class="flex-1 min-h-0 px-2 pb-3 m-0 overflow-y-auto list-none"
      role="listbox"
      :aria-label="t('CONVERSATION.SEARCH_IN_CONVERSATION.TITLE')"
      @scroll.passive="onListScroll"
    >
      <li
        v-for="(result, index) in decoratedResults"
        :key="result.id"
        role="option"
        :aria-selected="index === activeIndex"
        :data-result-index="index"
      >
        <button
          type="button"
          class="w-full px-3 py-2.5 text-left rounded-lg transition-colors hover:bg-n-alpha-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
          :class="{
            'bg-n-alpha-2': index === activeIndex,
            'opacity-60': jumpingId === result.id,
          }"
          @click="jumpTo(result, index)"
          @mouseenter="activeIndex = index"
        >
          <span class="flex items-center gap-2 mb-1 text-xs">
            <span class="font-medium truncate text-n-slate-12">
              {{ result.senderLabel }}
            </span>
            <span
              v-if="result.private"
              class="px-1.5 rounded font-medium shrink-0 bg-n-amber-3 text-n-amber-11"
            >
              {{ t('CONVERSATION.SEARCH_IN_CONVERSATION.NOTE') }}
            </span>
            <span
              class="ltr:ml-auto rtl:mr-auto shrink-0 tabular-nums text-n-slate-10"
            >
              {{ result.dateLabel }}
            </span>
          </span>
          <span
            v-if="result.segments.length"
            class="block text-sm leading-5 break-words line-clamp-3 text-n-slate-11"
          >
            <HighlightedText :segments="result.segments" />
          </span>
          <span
            v-for="file in result.files"
            :key="file.key"
            class="flex items-center min-w-0 gap-1 mt-1 text-xs text-n-slate-11"
          >
            <span
              class="i-lucide-paperclip size-3 shrink-0"
              aria-hidden="true"
            />
            <span class="truncate">
              <HighlightedText :segments="file.segments" />
            </span>
          </span>
        </button>
      </li>
      <li v-if="hasMore" class="flex justify-center py-3" role="presentation">
        <Spinner v-if="isLoading" :size="16" class="text-n-slate-10" />
        <Button
          v-else
          size="xs"
          variant="ghost"
          color="slate"
          :label="t('CONVERSATION.SEARCH_IN_CONVERSATION.LOAD_MORE')"
          @click="loadMore"
        />
      </li>
    </ul>
  </aside>
</template>
