<template>
  <BApp>
    <div id="app">
      <SkipLink />
      <div id="navbar">
        <AppNavbar />
      </div>
      <main id="main" ref="scroll" class="content-style scrollable-content" tabindex="-1">
        <router-view :key="$route.fullPath" />
      </main>
      <div id="footer">
        <AppFooter @show-disclaimer="disclaimerDialogVisible = true" />
      </div>

      <!--place the helper badge -->
      <HelperBadge />
      <!--place the helper badge -->

      <!-- PWA update prompt -->
      <ReloadPrompt />

      <!-- Disclaimer dialog (shown on first visit) -->
      <DisclaimerDialog
        v-model="disclaimerDialogVisible"
        @acknowledged="handleDisclaimerAcknowledged"
      />
    </div>
  </BApp>
</template>

<script>
import { provide } from 'vue';
import { useHead } from '@unhead/vue';
import { useToast } from 'bootstrap-vue-next';
import { useUiStore } from '@/stores/ui';
import { useDisclaimerStore } from '@/stores/disclaimer';
import { mapState } from 'pinia';
import AppNavbar from '@/components/AppNavbar.vue';
import AppFooter from '@/components/AppFooter.vue';
import HelperBadge from '@/components/HelperBadge.vue';
import SkipLink from '@/components/accessibility/SkipLink.vue';
import DisclaimerDialog from '@/components/disclaimer/DisclaimerDialog.vue';
import ReloadPrompt from '@/components/ReloadPrompt.vue';

export default {
  name: 'SysNDD',
  components: {
    AppNavbar,
    AppFooter,
    HelperBadge,
    SkipLink,
    DisclaimerDialog,
    ReloadPrompt,
  },
  setup() {
    useHead({
      title: 'SysNDD',
      titleTemplate:
        '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
      htmlAttrs: {
        lang: 'en',
      },
      meta: [
        {
          name: 'description',
          content:
            'SysNDD contains a manually curated catalog of published genes implicated in neurodevelopmental disorders (NDDs) and classified into primary and candidate genes according to the degree of underlying evidence.',
        },
      ],
    });

    // Initialize toast and provide to all child components
    const toast = useToast();
    provide('toast', toast);
  },
  data() {
    return {
      disclaimerDialogVisible: false,
    };
  },
  computed: {
    ...mapState(useUiStore, ['scrollbarUpdateTrigger']),
  },
  watch: {
    $route() {
      if (this.$refs.scroll) {
        this.$refs.scroll.scrollTop = 0;
      }
    },
    scrollbarUpdateTrigger: {
      handler() {
        // Native scrollbar doesn't need explicit update
        // This watcher kept for potential future scroll-to-top behavior
      },
    },
  },
  created() {
    const disclaimerStore = useDisclaimerStore();

    // Migrate from old Banner localStorage key if present
    if (!disclaimerStore.isAcknowledged && localStorage.getItem('banner_acknowledged')) {
      disclaimerStore.saveAcknowledgment();
      localStorage.removeItem('banner_acknowledged');
    }

    // Show disclaimer dialog if not yet acknowledged
    if (!disclaimerStore.isAcknowledged) {
      this.disclaimerDialogVisible = true;
    }
  },
  methods: {
    handleDisclaimerAcknowledged() {
      const disclaimerStore = useDisclaimerStore();
      disclaimerStore.saveAcknowledgment();
    },
  },
};
</script>

<style lang="scss">
@use '@/assets/scss/custom.scss' as custom;

:root {
  --app-navbar-height: 60px;
  --app-footer-height: 48px;
  --app-toast-offset: 0.75rem;
}

#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: custom.$text-main;
  margin-top: 0px;
}

body {
  padding-top: var(--app-navbar-height);
  padding-bottom: var(--app-footer-height);
  overflow: hidden;
}

.orchestrator-container {
  position: relative;
  z-index: 1045;
}

.toast-container.position-fixed {
  z-index: 1045;
  max-height: calc(
    100vh - var(--app-navbar-height) - var(--app-footer-height) -
      (var(--app-toast-offset) * 2) - env(safe-area-inset-top) - env(safe-area-inset-bottom)
  );
  overflow-y: auto;
  overscroll-behavior: contain;
  padding: 0 !important;
  pointer-events: none;
  scrollbar-gutter: stable;
}

.toast-container.top-0 {
  top: calc(
    var(--app-navbar-height) + var(--app-toast-offset) + env(safe-area-inset-top)
  ) !important;
}

.toast-container.bottom-0 {
  bottom: calc(
    var(--app-footer-height) + var(--app-toast-offset) + env(safe-area-inset-bottom)
  ) !important;
}

.toast-container.end-0 {
  right: max(1rem, env(safe-area-inset-right)) !important;
}

.toast-container.start-0 {
  left: max(1rem, env(safe-area-inset-left)) !important;
}

.toast-container .app-toast {
  width: min(var(--bs-toast-max-width, 360px), calc(100vw - 2rem));
  max-width: 100%;
  margin-bottom: 0.75rem;
  overflow: hidden;
  color: #1f2933 !important;
  text-align: left;
  background: rgba(255, 255, 255, 0.98) !important;
  border: 1px solid #d8e0ea;
  border-left: 4px solid #607d8b;
  border-radius: 8px;
  box-shadow:
    0 16px 40px rgba(15, 23, 42, 0.16),
    0 2px 8px rgba(15, 23, 42, 0.08);
  pointer-events: auto;
  backdrop-filter: blur(12px);
}

.toast-container .app-toast--success {
  border-left-color: #2e7d32;
}

.toast-container .app-toast--danger {
  border-left-color: #c62828;
}

.toast-container .app-toast--warning {
  border-left-color: #b7791f;
}

.toast-container .app-toast--info,
.toast-container .app-toast--primary {
  border-left-color: #0d47a1;
}

.toast-container .app-toast--secondary {
  border-left-color: #5f6b7a;
}

.toast-container .app-toast__header {
  gap: 0.5rem;
  padding: 0.75rem 0.85rem 0.2rem;
  color: #1f2933;
  font-size: 0.86rem;
  font-weight: 800;
  line-height: 1.2;
  background: transparent;
  border-bottom: 0;
}

.toast-container .app-toast__body {
  min-width: 0;
  padding: 0.35rem 0.85rem 0.85rem;
  color: #344054;
  font-size: 0.875rem;
  line-height: 1.35;
  overflow-wrap: anywhere;
}

.toast-container .app-toast .btn-close {
  flex: 0 0 auto;
  margin-left: 0.75rem;
  opacity: 0.58;
}

.toast-container .app-toast .btn-close:hover,
.toast-container .app-toast .btn-close:focus-visible {
  opacity: 0.86;
}

.toast-container .app-toast .progress {
  height: 3px !important;
  border-radius: 0;
  opacity: 0.4;
}

@media (max-width: 575.98px) {
  .toast-container.position-fixed {
    max-height: min(
      45vh,
      calc(
        100vh - var(--app-navbar-height) - var(--app-footer-height) -
          1rem - env(safe-area-inset-top) - env(safe-area-inset-bottom)
      )
    );
  }

  .toast-container.top-0 {
    top: calc(var(--app-navbar-height) + 0.5rem + env(safe-area-inset-top)) !important;
  }

  .toast-container.top-0,
  .toast-container.bottom-0 {
    right: max(0.75rem, env(safe-area-inset-right)) !important;
    left: max(0.75rem, env(safe-area-inset-left)) !important;
    width: auto !important;
    transform: none !important;
  }

  .toast-container .app-toast {
    width: 100%;
    margin-bottom: 0.5rem;
  }
}

// Native scrollbar styling
.scrollable-content {
  height: calc(100vh - var(--app-navbar-height) - var(--app-footer-height));
  overflow-y: auto;
  overflow-x: hidden;
}

// Optional: Custom scrollbar styling for webkit browsers
.scrollable-content::-webkit-scrollbar {
  width: 8px;
}

.scrollable-content::-webkit-scrollbar-track {
  background: #f1f1f1;
}

.scrollable-content::-webkit-scrollbar-thumb {
  background: #888;
  border-radius: 4px;
}

.scrollable-content::-webkit-scrollbar-thumb:hover {
  background: #555;
}
</style>
