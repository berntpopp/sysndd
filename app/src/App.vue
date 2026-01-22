<template>
  <div id="app">
    <div
      id="navbar"
    >
      <Navbar />
    </div>
    <perfect-scrollbar ref="scroll">
      <div
        id="content"
        class="content-style"
      >
        <router-view :key="$route.fullPath" />
      </div>
    </perfect-scrollbar>
    <div
      id="footer"
    >
      <Footer />
    </div>

    <!--place the helper badge -->
    <HelperBadge />
    <!--place the helper badge -->
  </div>
</template>

<script>
import { useUiStore } from '@/stores/ui';
import { mapState } from 'pinia';

export default {
  name: 'SysNDD',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'SysNDD',
    // all titles will be injected into this template
    titleTemplate:
      '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en',
    },
    meta: [
      {
        vmid: 'description',
        name: 'description',
        content:
          'SysNDD contains a manually curated catalog of published genes implicated in neurodevelopmental disorders (NDDs) and classified into primary and candidate genes according to the degree of underlying evidence.',
      },
    ],
  },
  computed: {
    ...mapState(useUiStore, ['scrollbarUpdateTrigger']),
  },
  watch: {
    $route() {
      this.$refs.scroll.$el.scrollTop = 0;
    },
    scrollbarUpdateTrigger: {
      handler() {
        this.updateScrollbar();
      },
      // No immediate: true - only react to changes after initial render
    },
  },
  methods: {
    updateScrollbar() {
      this.$nextTick(() => {
        if (this.$refs.scroll) {
          this.$refs.scroll.update();
        }
      });
    },
  },
};
</script>

<style lang="scss">
#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: $text-main;
  margin-top: 0px;
}

body {
  padding-top: 68px;
  padding-bottom: 50px;
  overflow: hidden;
}

.ps {
  height: calc(100vh - 116px);
}
</style>
