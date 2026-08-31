<script setup>
// Fork Valcenter: badge de status de conexão da caixa Evolution.
// status: 'open' | 'connecting' | 'close' | 'unknown'
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  status: { type: String, default: '' },
});

const { t } = useI18n();

const CONFIG = {
  open: {
    dot: 'bg-n-teal-9',
    text: 'text-n-teal-11',
    label: 'INBOX_MGMT.EVOLUTION.STATUS.CONNECTED',
    pulse: false,
  },
  connecting: {
    dot: 'bg-n-amber-9',
    text: 'text-n-amber-11',
    label: 'INBOX_MGMT.EVOLUTION.STATUS.CONNECTING',
    pulse: true,
  },
  close: {
    dot: 'bg-n-ruby-9',
    text: 'text-n-ruby-11',
    label: 'INBOX_MGMT.EVOLUTION.STATUS.DISCONNECTED',
    pulse: false,
  },
};

const config = computed(
  () =>
    CONFIG[props.status] || {
      dot: 'bg-n-slate-9',
      text: 'text-n-slate-10',
      label: 'INBOX_MGMT.EVOLUTION.STATUS.UNKNOWN',
      pulse: false,
    }
);
</script>

<template>
  <span class="inline-flex items-center gap-1.5" :class="config.text">
    <span
      class="size-2 rounded-full"
      :class="[config.dot, { 'animate-pulse': config.pulse }]"
    />
    <span class="text-body-main">{{ t(config.label) }}</span>
  </span>
</template>
