<script setup>
import { useI18n } from 'vue-i18n';

// URL of the external Group Management app, reverse-proxied by nginx on the
// same origin. Change this single constant to point the iframe elsewhere.
const GROUP_APP_URL = '/ext/dashboard-app/groups';

const { t } = useI18n();
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full min-h-0 overflow-hidden bg-n-surface-1"
  >
    <iframe
      :src="GROUP_APP_URL"
      :title="t('SIDEBAR.GROUP_MANAGEMENT')"
      class="w-full h-full border-0"
    />
  </div>
</template>
