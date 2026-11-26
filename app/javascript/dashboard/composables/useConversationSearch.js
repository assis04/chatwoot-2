import { readonly, ref } from 'vue';

// Fork Valcenter: estado unico da busca dentro da conversa. O botao fica no
// cabecalho (dentro do ConversationBox) e o painel e irmao do ConversationSidebar
// (ConversationView/InboxView), entao o estado e compartilhado em modulo.
const isOpen = ref(false);
// Muda a cada pedido de abrir, para o painel ja aberto devolver o foco ao campo
// (atalho apertado de novo).
const focusRequest = ref(0);

export function useConversationSearch() {
  const open = () => {
    isOpen.value = true;
    focusRequest.value += 1;
  };
  const close = () => {
    isOpen.value = false;
  };
  const toggle = () => (isOpen.value ? close() : open());

  return {
    isOpen: readonly(isOpen),
    focusRequest: readonly(focusRequest),
    open,
    close,
    toggle,
  };
}
