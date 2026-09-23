<script setup>
/**
 * Fork Valcenter — "Abrir conversa" a partir da aba Contatos, SEM enviar mensagem.
 *
 * Fluxo: ao clicar, busca as caixas em que o contato é alcançável
 * (contactable_inboxes). Se houver uma só, abre/cria direto; se houver várias,
 * mostra um dropdown para escolher o número. A criação NÃO manda mensagem nem
 * assignee — a conversa nasce sem dono. Com `lock_to_single_conversation=true`
 * (caixas Evolution), o backend reusa a conversa existente do contato naquele
 * número em vez de duplicar. A conversa nasce sem dono; o BACKEND adiciona o
 * próprio agente como participante (ConversationsController#ensure_creator_can_view)
 * pra ela ficar visível a funções restritivas ("participando") sem atribuir dono —
 * o front não pode fazer isso (POST /participants exige show? na conversa → 401).
 * Depois navega direto para a conversa.
 */
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { vOnClickOutside } from '@vueuse/components';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import {
  fetchContactableInboxes,
  buildContactableInboxesList,
} from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper';

import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  contactId: { type: [Number, String], required: true },
  label: { type: String, default: '' },
  variant: { type: String, default: 'link' },
  color: { type: String, default: 'slate' },
  size: { type: String, default: 'xs' },
  icon: { type: String, default: '' },
  // Alinhamento do dropdown das caixas em relação ao botão.
  dropdownClass: {
    type: String,
    default: 'ltr:left-0 rtl:right-0 top-8 max-h-56 w-fit max-w-sm',
  },
});

const { t } = useI18n();
const store = useStore();
const router = useRouter();

const isLoading = ref(false);
const showDropdown = ref(false);
const dropdownItems = ref([]);

const openConversation = async inbox => {
  if (!inbox) return;
  isLoading.value = true;
  showDropdown.value = false;
  try {
    const data = await store.dispatch('contactConversations/create', {
      params: {
        inboxId: inbox.id,
        sourceId: inbox.sourceId,
        contactId: Number(props.contactId),
      },
    });
    // A conversa nasce SEM DONO. O backend (ConversationsController#create ->
    // ensure_creator_can_view) adiciona o proprio agente como participante quando
    // nao ha assignee, tornando-a visivel a funcoes restritivas ("participando")
    // sem atribuir dono. O front NAO pode fazer isso (POST /participants exige
    // show? na conversa, que o agente ainda nao tem -> 401).
    await router.push(
      `/app/accounts/${data.account_id}/conversations/${data.id}`
    );
  } catch (error) {
    useAlert(t('CONTACTS_LAYOUT.OPEN_CONVERSATION.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const onClick = async () => {
  if (isLoading.value) return;
  if (showDropdown.value) {
    showDropdown.value = false;
    return;
  }

  isLoading.value = true;
  try {
    const inboxes = await fetchContactableInboxes(Number(props.contactId));
    isLoading.value = false;

    if (!inboxes.length) {
      useAlert(t('CONTACTS_LAYOUT.OPEN_CONVERSATION.NO_INBOX'));
      return;
    }
    if (inboxes.length === 1) {
      openConversation(inboxes[0]);
      return;
    }
    dropdownItems.value = buildContactableInboxesList(inboxes);
    showDropdown.value = true;
  } catch (error) {
    isLoading.value = false;
    useAlert(t('CONTACTS_LAYOUT.OPEN_CONVERSATION.ERROR'));
  }
};

const onInboxAction = item => {
  openConversation({ id: item.value, sourceId: item.sourceId });
};
</script>

<template>
  <div
    v-on-click-outside="() => (showDropdown = false)"
    class="relative inline-flex"
  >
    <Button
      :label="label || t('CONTACTS_LAYOUT.OPEN_CONVERSATION.BUTTON')"
      :variant="variant"
      :color="color"
      :size="size"
      :icon="icon"
      :is-loading="isLoading"
      :disabled="isLoading"
      @click="onClick"
    />
    <DropdownMenu
      v-if="showDropdown && dropdownItems.length"
      :menu-items="dropdownItems"
      :class="dropdownClass"
      class="z-[100] dark:!outline-n-slate-5"
      @action="onInboxAction"
    />
  </div>
</template>
