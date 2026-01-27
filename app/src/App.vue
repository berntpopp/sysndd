<template>
  <BApp>
    <div id="app">
      <SkipLink />
      <div
        id="navbar"
      >
        <AppNavbar />
      </div>
      <main
        id="main"
        ref="scroll"
        class="content-style scrollable-content"
        tabindex="-1"
      >
        <router-view :key="$route.fullPath" />
      </main>
      <div
        id="footer"
      >
        <AppFooter @show-disclaimer="disclaimerDialogVisible = true" />
      </div>

      <!--place the helper badge -->
      <HelperBadge />
      <!--place the helper badge -->

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

export default {
  name: 'SysNDD',
  components: {
    AppNavbar,
    AppFooter,
    HelperBadge,
    SkipLink,
    DisclaimerDialog,
  },
  setup() {
    useHead({
      title: 'SysNDD',
      titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
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
@use "@/assets/scss/custom.scss" as custom;

#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: custom.$text-main;
  margin-top: 0px;
}

body {
  padding-top: 68px;
  padding-bottom: 50px;
  overflow: hidden;
}

// Native scrollbar styling
.scrollable-content {
  height: calc(100vh - 116px);
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
