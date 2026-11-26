<script setup>
import Button from 'dashboard/components-next/button/Button.vue';
import { useConversationSearch } from 'dashboard/composables/useConversationSearch';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';

// Fork Valcenter: lupa no cabecalho da conversa — abre o painel de busca dentro
// da conversa. Atalho Ctrl/Cmd+Shift+F (o Ctrl+F do navegador continua livre).
const { isOpen, toggle, open } = useConversationSearch();

useKeyboardEvents({
  '$mod+Shift+KeyF': {
    action: event => {
      event.preventDefault();
      open();
    },
    allowOnFocusedInput: true,
  },
});
</script>

<template>
  <Button
    v-tooltip.bottom="$t('CONVERSATION.SEARCH_IN_CONVERSATION.BUTTON_TOOLTIP')"
    size="sm"
    variant="ghost"
    color="slate"
    icon="i-lucide-search"
    class="rounded-md"
    :class="{ 'bg-n-alpha-2 !text-n-slate-12': isOpen }"
    :aria-label="$t('CONVERSATION.SEARCH_IN_CONVERSATION.TITLE')"
    :aria-pressed="isOpen"
    @click="toggle"
  />
</template>
