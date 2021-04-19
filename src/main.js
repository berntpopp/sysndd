import '@fortawesome/fontawesome-free/css/all.min.css'
import 'mdbvue/lib/mdbvue.css'
import Vue from 'vue'
import App from './App.vue'

import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import 'bootstrap/dist/css/bootstrap.css'
import 'bootstrap-vue/dist/bootstrap-vue.css'

import VueAxios from 'vue-axios'
import axios from 'axios'

import router from './router'

import * as mdbvue from 'mdbvue'
for (const component in mdbvue) {
Vue.component(component, mdbvue[component])
}

Vue.component('Navbar', require('./components/Navbar.vue').default)

Vue.config.productionTip = false

Vue.use(VueAxios, axios)

// Make BootstrapVue available throughout your project
Vue.use(BootstrapVue)
// Optionally install the BootstrapVue icon components plugin
Vue.use(IconsPlugin)

new Vue({
  router,
  render: h => h(App)
}).$mount('#app')

