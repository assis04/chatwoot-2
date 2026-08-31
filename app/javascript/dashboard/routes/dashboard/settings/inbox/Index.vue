<script setup>
import { computed, onActivated, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { picoSearch } from '@scmmishra/pico-search';
import Avatar from 'next/avatar/Avatar.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import {
  getUserPermissions,
  hasPermissions,
} from 'dashboard/helper/permissionsHelper';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import {
  useMapGetter,
  useStoreGetters,
  useStore,
} from 'dashboard/composables/store';
import ChannelName from './components/ChannelName.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();
const { isAdmin } = useAdmin();

const currentUser = useMapGetter('getCurrentUser');
const currentAccountId = useMapGetter('getCurrentAccountId');

// Fork Valcenter: admin OU quem tem 'inbox_manage' pode abrir as configurações da
// caixa. Criar/apagar caixa segue só-admin (botões próprios continuam com isAdmin).
const canManageInboxes = computed(() => {
  if (isAdmin.value) return true;
  return hasPermissions(
    ['inbox_manage'],
    getUserPermissions(currentUser.value, currentAccountId.value)
  );
});

const showDeletePopup = ref(false);
const selectedInbox = ref({});
const searchQuery = ref('');

const inboxes = useMapGetter('inboxes/getInboxes');

onActivated(() => {
  store.dispatch('inboxes/get');
});

const inboxesList = computed(() => {
  return inboxes.value?.slice().sort((a, b) => a.name.localeCompare(b.name));
});

const filteredInboxesList = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return inboxesList.value;
  return picoSearch(inboxesList.value, query, ['name', 'channel_type']);
});

const uiFlags = computed(() => getters['inboxes/getUIFlags'].value);

const deleteConfirmText = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.YES')} ${selectedInbox.value.name}`
);

const deleteRejectText = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.NO')} ${selectedInbox.value.name}`
);

const confirmDeleteMessage = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.MESSAGE')} ${selectedInbox.value.name}?`
);
const confirmPlaceHolderText = computed(
  () =>
    `${t('INBOX_MGMT.DELETE.CONFIRM.PLACE_HOLDER', {
      inboxName: selectedInbox.value.name,
    })}`
);

const deleteInbox = async ({ id }) => {
  try {
    await store.dispatch('inboxes/delete', id);
    useAlert(t('INBOX_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.DELETE.API.ERROR_MESSAGE'));
  }
};
const closeDelete = () => {
  showDeletePopup.value = false;
  selectedInbox.value = {};
};

const confirmDeletion = () => {
  deleteInbox(selectedInbox.value);
  closeDelete();
};
const openDelete = inbox => {
  showDeletePopup.value = true;
  selectedInbox.value = inbox;
};

// Fork Valcenter: caixas Evolution (Channel::Api) guardam o número do WhatsApp em
// additional_attributes.phone_number (backfill a partir do ownerJid da instância).
// Formata BR em E.164 -> +55 (11) 98765-4321; se não reconhecer, mostra como veio.
const inboxPhoneNumber = inbox => {
  const raw = inbox?.additional_attributes?.phone_number || inbox?.phone_number;
  return raw ? String(raw).trim() : '';
};

const formatPhoneNumber = value => {
  const digits = String(value).replace(/\D/g, '');
  if (digits.startsWith('55') && (digits.length === 12 || digits.length === 13)) {
    const ddd = digits.slice(2, 4);
    const rest = digits.slice(4);
    const mid = rest.length === 9 ? rest.slice(0, 5) : rest.slice(0, 4);
    const end = rest.length === 9 ? rest.slice(5) : rest.slice(4);
    return `+55 (${ddd}) ${mid}-${end}`;
  }
  return value.startsWith('+') ? value : `+${digits}`;
};
</script>

<template>
  <SettingsLayout
    :no-records-found="!inboxesList.length"
    :no-records-message="$t('INBOX_MGMT.LIST.404')"
    :is-loading="uiFlags.isFetching"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('INBOX_MGMT.HEADER')"
        :description="$t('INBOX_MGMT.DESCRIPTION')"
        :link-text="$t('INBOX_MGMT.LEARN_MORE')"
        :search-placeholder="$t('INBOX_MGMT.SEARCH_PLACEHOLDER')"
        feature-name="inboxes"
      >
        <template v-if="inboxesList?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('INBOX_MGMT.COUNT', { n: inboxesList.length }) }}
          </span>
        </template>
        <template #actions>
          <router-link v-if="isAdmin" :to="{ name: 'settings_inbox_new' }">
            <Button :label="$t('SETTINGS.INBOXES.NEW_INBOX')" size="sm" />
          </router-link>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <span
        v-if="!filteredInboxesList.length && searchQuery"
        class="flex-1 flex items-center justify-center py-20 text-center text-body-main !text-base text-n-slate-11"
      >
        {{ $t('INBOX_MGMT.NO_RESULTS') }}
      </span>
      <div v-else class="divide-y divide-n-weak border-t border-n-weak">
        <div
          v-for="inbox in filteredInboxesList"
          :key="inbox.id"
          class="flex justify-between flex-row items-start gap-4 py-4"
        >
          <div class="flex items-center gap-4">
            <div
              v-if="inbox.avatar_url"
              class="bg-n-alpha-3 rounded-xl size-10 ring ring-n-solid-1 border border-n-strong shadow-sm grid place-items-center"
            >
              <Avatar
                :src="inbox.avatar_url"
                :name="inbox.name"
                :size="24"
                rounded-full
              />
            </div>
            <div
              v-else
              class="size-10 justify-center bg-n-alpha-3 rounded-xl ring ring-n-solid-1 border border-n-strong shadow-sm grid place-items-center"
            >
              <ChannelIcon class="size-6 text-n-slate-10" :inbox="inbox" />
            </div>
            <div class="flex flex-col items-start gap-1">
              <span class="block text-heading-3 text-n-slate-12 capitalize">
                {{ inbox.name }}
              </span>
              <div
                class="flex items-center gap-2 text-body-main text-n-slate-11"
              >
                <ChannelName
                  :channel-type="inbox.channel_type"
                  :medium="inbox.medium"
                  :voice-enabled="inbox.voice_enabled"
                />
                <template v-if="inboxPhoneNumber(inbox)">
                  <span class="text-n-slate-9" aria-hidden="true">·</span>
                  <span class="tabular-nums">
                    {{ formatPhoneNumber(inboxPhoneNumber(inbox)) }}
                  </span>
                </template>
              </div>
            </div>
          </div>
          <div class="flex gap-3 justify-end">
            <router-link
              :to="{
                name: 'settings_inbox_show',
                params: { inboxId: inbox.id },
              }"
            >
              <Button
                v-if="canManageInboxes"
                v-tooltip.top="$t('INBOX_MGMT.SETTINGS')"
                icon="i-woot-settings"
                slate
                sm
              />
            </router-link>
            <Button
              v-if="isAdmin"
              v-tooltip.top="$t('INBOX_MGMT.DELETE.BUTTON_TEXT')"
              icon="i-woot-bin"
              slate
              sm
              class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
              @click="openDelete(inbox)"
            />
          </div>
        </div>
      </div>
    </template>

    <woot-confirm-delete-modal
      v-if="showDeletePopup"
      v-model:show="showDeletePopup"
      :title="$t('INBOX_MGMT.DELETE.CONFIRM.TITLE')"
      :message="confirmDeleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
      :confirm-value="selectedInbox.name"
      :confirm-place-holder-text="confirmPlaceHolderText"
      @on-confirm="confirmDeletion"
      @on-close="closeDelete"
    />
  </SettingsLayout>
</template>
