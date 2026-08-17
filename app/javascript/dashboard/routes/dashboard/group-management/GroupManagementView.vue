<script setup>
import { ref, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import axios from 'axios';

// URL of the external Group Management app, reverse-proxied by nginx on the same
// origin. We append a short-lived, signed context token (`ctx`) so the app knows
// which WhatsApp numbers this agent may see: an admin sees every number, an agent
// only the inboxes they belong to. The token is minted server-side and verified
// by the app with a shared secret — the browser cannot forge or widen the scope.
const GROUP_APP_URL = '/ext/dashboard-app/groups';

const { t } = useI18n();
const route = useRoute();

const iframeSrc = ref('');
const failed = ref(false);

onMounted(async () => {
  try {
    const { accountId } = route.params;
    const { data } = await axios.get(
      `/api/v1/accounts/${accountId}/group_management/context_token`
    );
    iframeSrc.value = `${GROUP_APP_URL}?ctx=${encodeURIComponent(data.token)}`;
  } catch (error) {
    failed.value = true;
  }
});
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full min-h-0 overflow-hidden bg-n-surface-1"
  >
    <div
      v-if="failed"
      class="flex items-center justify-center flex-1 text-sm text-n-slate-11"
    >
      {{ t('SIDEBAR.GROUP_MANAGEMENT') }} — não foi possível autenticar. Recarregue
      a página.
    </div>
    <iframe
      v-else-if="iframeSrc"
      :src="iframeSrc"
      :title="t('SIDEBAR.GROUP_MANAGEMENT')"
      class="w-full h-full border-0"
    />
  </div>
</template>
