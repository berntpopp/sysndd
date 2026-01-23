<template>
  <BApp>
    <div id="app">
      <div
        id="navbar"
      >
        <Navbar />
      </div>
      <div
        id="content"
        ref="scroll"
        class="content-style scrollable-content"
      >
        <router-view :key="$route.fullPath" />
      </div>
      <div
        id="footer"
      >
        <Footer />
      </div>

      <!--place the helper badge -->
      <HelperBadge />
      <!--place the helper badge -->
    </div>
  </BApp>
</template>

<script>
import { provide } from 'vue';
import { useHead } from '@unhead/vue';
import { useToast } from 'bootstrap-vue-next';
import { useUiStore } from '@/stores/ui';
import { mapState } from 'pinia';

export default {
  name: 'SysNDD',
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
