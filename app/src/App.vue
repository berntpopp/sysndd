<template>
  <div id="app">
    <div id="navbar" class="sticky-top"> <Navbar/> </div>
    <div id="content" class="position-relative" style="min-height:calc(100vh - 100px)"> <router-view></router-view> </div>
    <div id="footer" class="sticky-bottom"> <Footer/> </div>
  </div>
</template>

<script>
import Navbar from './components/Navbar.vue'
import Footer from './components/Footer.vue'

export default {
  name: 'SysNDD',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'SysNDD',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'SysNDD contains a manually curated catalogue of published genes implicated in neurodevelopmental disorders (NDDs) and classified into primary and candidate genes according to the degree of underlying evidence.' }
    ]
  },
  components: {
    Navbar,
    Footer
  }
}
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
  position: relative;
  min-height: 100vh;
}

.footer {
  width: 100%;
}

.spinner {
  min-height: 100%;
}
</style>
