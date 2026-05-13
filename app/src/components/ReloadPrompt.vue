<template>
  <div v-if="needRefresh" class="reload-prompt" role="status" aria-live="polite">
    <div class="reload-prompt__icon" aria-hidden="true">
      <i class="bi bi-arrow-clockwise"></i>
    </div>
    <div class="reload-prompt__copy">
      <span class="reload-prompt__title">New SysNDD version available</span>
      <span class="reload-prompt__text">Refresh when ready to load the latest app shell.</span>
    </div>
    <div class="reload-prompt__actions">
      <button class="btn btn-sm btn-primary" @click="updateServiceWorker(true)">Update</button>
      <button class="btn btn-sm btn-link reload-prompt__dismiss" @click="close">Later</button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onUnmounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useRegisterSW } from 'virtual:pwa-register/vue';
import { usePwaUpdateChecks } from '@/composables/usePwaUpdateChecks';

const route = useRoute();
const updateChecks = usePwaUpdateChecks();

const { needRefresh, updateServiceWorker } = useRegisterSW({
  onRegisteredSW(swUrl: string, registration: ServiceWorkerRegistration | undefined) {
    updateChecks.registerServiceWorker(swUrl, registration);
  },
  onRegisterError(error: unknown) {
    console.error('SW registration error:', error);
  },
});

watch(
  () => route.fullPath,
  () => {
    void updateChecks.checkForUpdate('route');
  }
);

onUnmounted(() => {
  updateChecks.stop();
});

function close() {
  needRefresh.value = false;
}
</script>

<style scoped>
.reload-prompt {
  position: fixed;
  right: 1rem;
  bottom: calc(var(--app-footer-height, 48px) + 1rem + env(safe-area-inset-bottom));
  z-index: 1060;
  background: #fff;
  border: 1px solid rgba(33, 37, 41, 0.12);
  border-radius: 0.75rem;
  padding: 0.65rem;
  box-shadow:
    0 18px 45px rgba(15, 23, 42, 0.16),
    0 2px 8px rgba(15, 23, 42, 0.08);
  display: flex;
  align-items: center;
  gap: 0.65rem;
  width: min(25rem, calc(100vw - 2rem));
  color: #17202a;
}

.reload-prompt__icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  flex: 0 0 2rem;
  border-radius: 0.6rem;
  background: #e9f3ff;
  color: #0f5fb8;
}

.reload-prompt__copy {
  min-width: 0;
  display: grid;
  gap: 0.05rem;
  flex: 1 1 auto;
}

.reload-prompt__title {
  font-size: 0.875rem;
  font-weight: 700;
  line-height: 1.2;
}

.reload-prompt__text {
  font-size: 0.78rem;
  line-height: 1.25;
  color: #52606d;
}

.reload-prompt__actions {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  flex: 0 0 auto;
}

.reload-prompt__dismiss {
  color: #52606d;
  text-decoration: none;
  padding-inline: 0.35rem;
}

@media (max-width: 575.98px) {
  .reload-prompt {
    right: 0.75rem;
    bottom: calc(var(--app-footer-height, 48px) + 0.75rem + env(safe-area-inset-bottom));
    align-items: flex-start;
  }

  .reload-prompt__actions {
    align-self: center;
    flex-direction: column;
  }
}
</style>
