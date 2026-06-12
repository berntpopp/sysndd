// Hash-driven tab navigation for the LLM Administration view. Extracted from
// ManageLLM.vue so the view stays a thinner shell. Owns the tab catalog,
// active-tab ref, and the hashchange/popstate listeners.

import { onMounted, onUnmounted, ref, type Ref } from 'vue';

export type LlmAdminTabId = 'overview' | 'configuration' | 'prompts' | 'cache' | 'logs';

export interface LlmAdminTab {
  id: LlmAdminTabId;
  label: string;
  hash: string;
}

export const llmAdminTabs: LlmAdminTab[] = [
  { id: 'overview', label: 'Overview', hash: '#overview' },
  { id: 'configuration', label: 'Configuration', hash: '#configuration' },
  { id: 'prompts', label: 'Prompts', hash: '#prompts' },
  { id: 'cache', label: 'Cache', hash: '#cache' },
  { id: 'logs', label: 'Logs', hash: '#logs' },
];

export interface UseLlmAdminTabs {
  tabs: LlmAdminTab[];
  activeTab: Ref<LlmAdminTabId>;
  setActiveTab: (tabId: LlmAdminTabId) => void;
  syncActiveTabFromLocation: () => void;
}

function tabFromHash(hash: string): LlmAdminTabId {
  const normalized = hash.replace(/^#/, '');
  return llmAdminTabs.find((tab) => tab.id === normalized)?.id ?? 'overview';
}

export function useLlmAdminTabs(): UseLlmAdminTabs {
  const activeTab = ref<LlmAdminTabId>('overview');

  function syncActiveTabFromLocation() {
    activeTab.value = tabFromHash(window.location.hash);
  }

  function setActiveTab(tabId: LlmAdminTabId) {
    activeTab.value = tabId;
  }

  onMounted(() => {
    syncActiveTabFromLocation();
    window.addEventListener('hashchange', syncActiveTabFromLocation);
    window.addEventListener('popstate', syncActiveTabFromLocation);
  });

  onUnmounted(() => {
    window.removeEventListener('hashchange', syncActiveTabFromLocation);
    window.removeEventListener('popstate', syncActiveTabFromLocation);
  });

  return {
    tabs: llmAdminTabs,
    activeTab,
    setActiveTab,
    syncActiveTabFromLocation,
  };
}
