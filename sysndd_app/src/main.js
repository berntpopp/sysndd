import Vue from 'vue'
import App from './App.vue'

import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import 'bootstrap/dist/css/bootstrap.css'
import 'bootstrap-vue/dist/bootstrap-vue.css'
import Multiselect from 'vue-multiselect'
import 'vue-multiselect/dist/vue-multiselect.min.css'

import VueAxios from 'vue-axios'
import axios from 'axios'

import router from './router'

Vue.component('Navbar', require('./components/Navbar.vue').default)

Vue.config.productionTip = false

Vue.use(VueAxios, axios)

// Make BootstrapVue available throughout your project
Vue.use(BootstrapVue)
// Optionally install the BootstrapVue icon components plugin
Vue.use(IconsPlugin)

// register vue-multiselect globally
Vue.component('multiselect', Multiselect)
Vue.use(Multiselect)

new Vue({
  router,
  render: h => h(App)
}).$mount('#app')

