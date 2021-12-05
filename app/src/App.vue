<template>
  <div id="app">
    <Navbar/>
    <router-view></router-view>
    <Footer/>
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
    titleTemplate: '%s | The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { charset: 'utf-8' },
      { name: 'description', content: 'The SysNDD database is based on its predecessor database, SysID. It contains a manually curated catalogue of published genes implicated in neurodevelopmental disorders (NDDs) and classified into primary and candidate genes according to the degree of underlying evidence.' }
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
  color: #2c3e50;
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
