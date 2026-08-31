<script setup>
// Fork Valcenter: modal de reconexão da caixa Evolution. Pede o QR ao Chatwoot
// (que proxia a Evolution), renova o QR periodicamente (expira ~30s) e faz
// polling do status até conectar — aí fecha sozinho. Auto-gerencia os timers.
import { ref, onBeforeUnmount, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import InboxesAPI from 'dashboard/api/inboxes';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  inboxId: { type: [Number, String], default: null },
  inboxName: { type: String, default: '' },
});
const emit = defineEmits(['close', 'connected']);

const { t } = useI18n();

const STATUS_POLL_MS = 3000;
const QR_REFRESH_MS = 25000;

const qrcode = ref('');
const pairingCode = ref('');
const isLoading = ref(false);
const isConnected = ref(false);
const errorMessage = ref('');

let statusTimer = null;
let refreshTimer = null;

const clearTimers = () => {
  if (statusTimer) clearInterval(statusTimer);
  if (refreshTimer) clearInterval(refreshTimer);
  statusTimer = null;
  refreshTimer = null;
};

const onConnected = () => {
  if (isConnected.value) return;
  isConnected.value = true;
  clearTimers();
  emit('connected');
  setTimeout(() => emit('close'), 1600);
};

const fetchQr = async () => {
  if (!props.inboxId) return;
  isLoading.value = !qrcode.value;
  errorMessage.value = '';
  try {
    const { data } = await InboxesAPI.evolutionConnect(props.inboxId);
    if (data.status === 'open') {
      onConnected();
    } else if (data.status === 'qrcode' && data.qrcode) {
      qrcode.value = data.qrcode;
      pairingCode.value = data.pairing_code || '';
    } else {
      errorMessage.value = t('INBOX_MGMT.EVOLUTION.QR.ERROR');
    }
  } catch (error) {
    errorMessage.value = t('INBOX_MGMT.EVOLUTION.QR.ERROR');
  } finally {
    isLoading.value = false;
  }
};

const checkStatus = async () => {
  if (!props.inboxId) return;
  try {
    const { data } = await InboxesAPI.getEvolutionStatus(props.inboxId);
    if (data.status === 'open') onConnected();
  } catch (error) {
    // silencioso — o polling continua
  }
};

const start = async () => {
  clearTimers();
  isConnected.value = false;
  qrcode.value = '';
  pairingCode.value = '';
  await fetchQr();
  if (!isConnected.value) {
    statusTimer = setInterval(checkStatus, STATUS_POLL_MS);
    refreshTimer = setInterval(fetchQr, QR_REFRESH_MS);
  }
};

onBeforeUnmount(clearTimers);

watch(
  () => props.inboxId,
  id => {
    if (id) start();
    else clearTimers();
  },
  { immediate: true }
);
</script>

<template>
  <woot-modal :show="true" :on-close="() => emit('close')">
    <div class="flex flex-col items-center gap-4 p-8 text-center">
      <h3 class="text-lg font-medium text-n-slate-12">
        {{ t('INBOX_MGMT.EVOLUTION.QR.TITLE') }}
        <span class="text-n-slate-11">— {{ inboxName }}</span>
      </h3>

      <!-- Conectado -->
      <div
        v-if="isConnected"
        class="flex flex-col items-center gap-3 py-6"
      >
        <span
          class="grid size-16 place-items-center rounded-full bg-n-teal-3 text-3xl font-bold text-n-teal-11"
        >
          ✓
        </span>
        <p class="text-base font-medium text-n-teal-11">
          {{ t('INBOX_MGMT.EVOLUTION.QR.CONNECTED') }}
        </p>
      </div>

      <!-- Erro -->
      <div
        v-else-if="errorMessage"
        class="flex flex-col items-center gap-4 py-6"
      >
        <p class="text-sm text-n-ruby-11">{{ errorMessage }}</p>
        <Button
          :label="t('INBOX_MGMT.EVOLUTION.QR.REFRESH')"
          size="sm"
          @click="fetchQr"
        />
      </div>

      <!-- Carregando / QR -->
      <template v-else>
        <p class="max-w-sm text-sm text-n-slate-11">
          {{ t('INBOX_MGMT.EVOLUTION.QR.INSTRUCTIONS') }}
        </p>

        <div
          class="grid size-64 place-items-center overflow-hidden rounded-xl border border-n-weak bg-white"
        >
          <woot-spinner v-if="isLoading" />
          <img
            v-else-if="qrcode"
            :src="qrcode"
            alt="QR code"
            class="size-full object-contain"
          />
        </div>

        <div v-if="pairingCode" class="text-sm text-n-slate-11">
          {{ t('INBOX_MGMT.EVOLUTION.QR.PAIRING_CODE') }}
          <span class="font-mono font-semibold text-n-slate-12 tracking-wider">
            {{ pairingCode }}
          </span>
        </div>

        <Button
          :label="t('INBOX_MGMT.EVOLUTION.QR.CLOSE')"
          color="slate"
          size="sm"
          variant="faded"
          @click="() => emit('close')"
        />
      </template>
    </div>
  </woot-modal>
</template>
