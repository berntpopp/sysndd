import Vue from 'vue'
import App from './App.vue'

import { IconsPlugin } from 'bootstrap-vue'
import 'bootstrap/dist/css/bootstrap.css'
import 'bootstrap-vue/dist/bootstrap-vue.css'
import Multiselect from 'vue-multiselect'
import 'vue-multiselect/dist/vue-multiselect.min.css'

import VueAxios from 'vue-axios'
import axios from 'axios'

import router from './router'

// vee-validate imports
import {
  ValidationObserver,
  ValidationProvider,
  extend,
  localize
} from "vee-validate";
import en from "vee-validate/dist/locale/en.json";
import * as rules from "vee-validate/dist/rules";

Vue.component('Navbar', require('./components/Navbar.vue').default)

Vue.config.productionTip = false

Vue.use(VueAxios, axios)

import { ToastPlugin } from 'bootstrap-vue'
Vue.use(ToastPlugin)

// Install the BootstrapVue icon components plugin
Vue.use(IconsPlugin)

// register vue-multiselect globally
Vue.component('multiselect', Multiselect)
Vue.use(Multiselect)

// Install VeeValidate rules and localization (based on https://codesandbox.io/s/boostrapvue-veevalidate-v3-example-xm3et?from-embed=&file=/index.js)
Object.keys(rules).forEach(rule => {
  extend(rule, rules[rule]);
});

localize("en", en);

// Install VeeValidate components globally
Vue.component("ValidationObserver", ValidationObserver);
Vue.component("ValidationProvider", ValidationProvider);

new Vue({
  router,
  render: h => h(App)
}).$mount('#app')

