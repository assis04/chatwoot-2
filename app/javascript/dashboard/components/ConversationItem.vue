<script setup>
import { computed, ref, watch, inject } from 'vue';
import { useRouter } from 'vue-router';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import ConversationCard from './widgets/conversation/ConversationCard.vue';
import ConversationCardExpanded from 'dashboard/components-next/Conversation/ConversationCard/ConversationCardExpanded.vue';
import ContextMenu from 'dashboard/components/ui/ContextMenu.vue';
import ConversationContextMenu from './widgets/conversation/contextMenu/Index.vue';

const props = defineProps({
  source: { type: Object, required: true },
  teamId: { type: [String, Number], default: 0 },
  label: { type: String, default: '' },
  conversationType: { type: String, default: '' },
  foldersId: { type: [String, Number], default: 0 },
  showAssignee: { type: Boolean, default: false },
  showExpanded: { type: Boolean, default: false },
});

const router = useRouter();
const store = useStore();

const selectConversation = inject('selectConversation');
const deSelectConversation = inject('deSelectConversation');
const assignAgent = inject('assignAgent');
const assignTeam = inject('assignTeam');
const assignLabels = inject('assignLabels');
const removeLabels = inject('removeLabels');
const updateConversationStatus = inject('updateConversationStatus');
const toggleContextMenu = inject('toggleContextMenu');
const markAsUnread = inject('markAsUnread');
const markAsRead = inject('markAsRead');
const assignPriority = inject('assignPriority');
const isConversationSelected = inject('isConversationSelected');
const deleteConversation = inject('deleteConversation');

// --- Context menu state (shared by both layouts) ---
const showContextMenu = ref(false);
const contextMenu = ref({ x: null, y: null });

// Reset context menu state when the row is recycled to a different conversation.
watch(
  () => props.source.id,
  () => {
    if (showContextMenu.value) {
      toggleContextMenu(false);
    }
    showContextMenu.value = false;
    contextMenu.value = { x: null, y: null };
  }
);

const currentChat = useMapGetter('getSelectedChat');
const inboxesList = useMapGetter('inboxes/getInboxes');
const activeInbox = useMapGetter('getSelectedInbox');
const accountId = useMapGetter('getCurrentAccountId');

const chatMetadata = computed(() => props.source.meta || {});
const assignee = computed(() => chatMetadata.value.assignee || {});
const senderId = computed(() => chatMetadata.value.sender?.id);

const currentContact = computed(() =>
  senderId.value ? store.getters['contacts/getContact'](senderId.value) : {}
);

const isActiveChat = computed(() => currentChat.value.id === props.source.id);

const inbox = computed(() => {
  const inboxId = props.source.inbox_id;
  if (!inboxId) return {};
  // Fork: com a visibilidade cross-número (Digisac), um agente vê conversas de
  // inboxes das quais NÃO é membro, então a inbox pode não estar no store local
  // dele. Caímos num objeto mínimo com o id pra o menu de contexto / atribuição
  // (que dependem do inbox_id) continuarem funcionando — senão o dropdown de
  // agentes vem vazio ("None") nessas conversas.
  return store.getters['inboxes/getInbox'](inboxId) || { id: inboxId };
});

// Fork: participantes (watchers) atuais da conversa, pra marcar no submenu
// "Participantes" do menu de contexto.
const participantIds = computed(() => {
  const list =
    store.getters['conversationWatchers/getByConversationId'](
      props.source.id
    ) || [];
  return list.map(user => user.id);
});

const showInboxName = computed(
  () => !activeInbox.value && inboxesList.value.length > 1
);
const isInboxView = computed(() => !!activeInbox.value);
const showAssigneeForExpandedCard = computed(
  () => props.showExpanded || props.showAssignee
);

const conversationPath = computed(() =>
  frontendURL(
    conversationUrl({
      accountId: accountId.value,
      activeInbox: activeInbox.value,
      id: props.source.id,
      label: props.label,
      teamId: props.teamId,
      conversationType: props.conversationType,
      foldersId: props.foldersId,
    })
  )
);

const onCardClick = e => {
  const path = conversationPath.value;
  if (!path) return;

  if (e.metaKey || e.ctrlKey) {
    e.preventDefault();
    window.open(
      `${window.chatwootConfig.hostURL}${path}`,
      '_blank',
      'noopener,noreferrer'
    );
    return;
  }

  if (isActiveChat.value) return;
  router.push({ path });
};

const onExpandedSelect = checked => {
  if (checked) {
    selectConversation(props.source.id, inbox.value.id);
  } else {
    deSelectConversation(props.source.id, inbox.value.id);
  }
};

const openContextMenu = e => {
  e.preventDefault();
  toggleContextMenu(true);
  contextMenu.value.x = e.pageX || e.clientX;
  contextMenu.value.y = e.pageY || e.clientY;
  showContextMenu.value = true;
  // Fork: carrega os participantes atuais pra o submenu "Participantes" já vir
  // com os que estão marcados.
  store.dispatch('conversationWatchers/show', {
    conversationId: props.source.id,
  });
};

const closeContextMenu = () => {
  toggleContextMenu(false);
  showContextMenu.value = false;
  contextMenu.value.x = null;
  contextMenu.value.y = null;
};

const onUpdateConversation = (status, snoozedUntil) => {
  closeContextMenu();
  updateConversationStatus(props.source.id, status, snoozedUntil);
};

const onAssignAgent = agent => {
  assignAgent(agent, [props.source.id]);
  closeContextMenu();
};

const onAssignLabel = label => {
  assignLabels([label.title], [props.source.id]);
};

const onRemoveLabel = label => {
  removeLabels([label.title], [props.source.id]);
};

const onAssignTeam = team => {
  assignTeam(team, props.source.id);
  closeContextMenu();
};

const onMarkAsUnread = () => {
  markAsUnread(props.source.id);
  closeContextMenu();
};

const onMarkAsRead = () => {
  markAsRead(props.source.id);
  closeContextMenu();
};

const onAssignPriority = priority => {
  assignPriority(priority, props.source.id);
  closeContextMenu();
};

const onDeleteConversation = () => {
  deleteConversation(props.source.id);
  closeContextMenu();
};

// Fork: adiciona/remove um agente como participante (watcher) da conversa.
// Não fecha o menu — permite marcar/desmarcar vários de uma vez.
const onToggleParticipant = agent => {
  const current =
    store.getters['conversationWatchers/getByConversationId'](
      props.source.id
    ) || [];
  const isParticipant = current.some(user => user.id === agent.id);
  const userIds = isParticipant
    ? current.filter(user => user.id !== agent.id).map(user => user.id)
    : [...current.map(user => user.id), agent.id];
  store
    .dispatch('conversationWatchers/update', {
      conversationId: props.source.id,
      userIds,
    })
    .then(() =>
      store.dispatch('conversationWatchers/show', {
        conversationId: props.source.id,
      })
    );
};
</script>

<template>
  <!-- Expanded layout: wide screen + expanded setting -->
  <ConversationCardExpanded
    v-if="showExpanded"
    :chat="source"
    :current-contact="currentContact"
    :assignee="assignee"
    :inbox="inbox"
    :selected="isConversationSelected(source.id)"
    :is-active-chat="isActiveChat"
    :show-assignee="showAssigneeForExpandedCard"
    :show-inbox-name="showInboxName"
    :is-inbox-view="isInboxView"
    @select-conversation="onExpandedSelect"
    @de-select-conversation="onExpandedSelect"
    @click="onCardClick"
    @contextmenu="openContextMenu"
  />

  <!-- Default (condensed) layout -->
  <ConversationCard
    v-else
    :chat="source"
    :current-contact="currentContact"
    :assignee="assignee"
    :inbox="inbox"
    :selected="isConversationSelected(source.id)"
    :is-active-chat="isActiveChat"
    :show-assignee="showAssignee"
    :show-inbox-name="showInboxName"
    @click="onCardClick"
    @contextmenu="openContextMenu"
    @select-conversation="selectConversation"
    @de-select-conversation="deSelectConversation"
  />

  <!-- Shared context menu for both layouts -->
  <ContextMenu
    v-if="showContextMenu"
    :x="contextMenu.x"
    :y="contextMenu.y"
    @close="closeContextMenu"
  >
    <ConversationContextMenu
      :status="source.status"
      :inbox-id="inbox.id"
      :priority="source.priority"
      :chat-id="source.id"
      :has-unread-messages="source.unread_count > 0"
      :conversation-labels="source.labels"
      :conversation-url="conversationPath"
      :participant-ids="participantIds"
      @update-conversation="onUpdateConversation"
      @assign-agent="onAssignAgent"
      @assign-label="onAssignLabel"
      @remove-label="onRemoveLabel"
      @assign-team="onAssignTeam"
      @toggle-participant="onToggleParticipant"
      @mark-as-unread="onMarkAsUnread"
      @mark-as-read="onMarkAsRead"
      @assign-priority="onAssignPriority"
      @delete-conversation="onDeleteConversation"
      @close="closeContextMenu"
    />
  </ContextMenu>
</template>
