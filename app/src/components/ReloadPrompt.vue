<template>
  <div v-if="needRefresh" class="reload-prompt" role="alert">
    <span>A new version of SysNDD is available.</span>
    <button class="btn btn-sm btn-primary ms-2" @click="updateServiceWorker(true)">
      Update now
    </button>
    <button class="btn btn-sm btn-outline-secondary ms-1" @click="close">Dismiss</button>
  </div>
</template>

<script setup lang="ts">
import { useRegisterSW } from 'virtual:pwa-register/vue';

const intervalMS = 60 * 60 * 1000; // Check for updates every 60 minutes

const { needRefresh, updateServiceWorker } = useRegisterSW({
  onRegisteredSW(_swUrl: string, registration: ServiceWorkerRegistration | undefined) {
    if (registration) {
      setInterval(() => {
        registration.update();
      }, intervalMS);
    }
  },
  onRegisterError(error: unknown) {
    console.error('SW registration error:', error);
  },
});

function close() {
  needRefresh.value = false;
}
</script>

<style scoped>
.reload-prompt {
  position: fixed;
  bottom: 60px;
  right: 16px;
  z-index: 1060;
  background: #fff;
  border: 1px solid #dee2e6;
  border-radius: 6px;
  padding: 12px 16px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  display: flex;
  align-items: center;
  font-size: 0.9rem;
}
</style>
