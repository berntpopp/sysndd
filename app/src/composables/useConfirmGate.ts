// composables/useConfirmGate.ts
//
// Small reusable gate that defers a heavy / irreversible action behind a
// confirmation modal (pairs with ConfirmActionModal). Call request(config,
// action) to open the modal; accept() runs the pending action; the @hidden
// lifecycle should call reset() so a dismissed gate never leaves a stale
// pending action.

import { ref } from 'vue';

export interface ConfirmGateConfig {
  title: string;
  message: string;
  confirmLabel?: string;
  confirmVariant?: 'primary' | 'secondary' | 'success' | 'danger' | 'warning' | 'info';
}

export function useConfirmGate() {
  const open = ref(false);
  const config = ref<ConfirmGateConfig>({ title: '', message: '' });
  let pending: (() => void | Promise<void>) | null = null;

  function request(cfg: ConfirmGateConfig, action: () => void | Promise<void>): void {
    config.value = cfg;
    pending = action;
    open.value = true;
  }

  function accept(): void {
    open.value = false;
    const action = pending;
    pending = null;
    void action?.();
  }

  function reset(): void {
    pending = null;
  }

  return { open, config, request, accept, reset };
}
