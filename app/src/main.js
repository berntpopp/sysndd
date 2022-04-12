import Vue from 'vue'
import App from './App.vue'
import VueMeta from 'vue-meta'

import './assets/css/custom.css';
import './assets/js/functions.js';

import { BIconPersonCircle, 
  BIconStoplights, 
  BIconFilter, 
  BIconSearch, 
  BIconCheck, 
  BIconX, 
  BIconXCircle, 
  BIconArrowRepeat, 
  BIconEye, 
  BIconEyeSlash, 
  BIconPen, 
  BIconCheck2Circle, 
  BIconHandThumbsUp, 
  BIconHandThumbsDown, 
  BIconBoxArrowUpRight, 
  BIconTable,
  BIconDownload,
  BIconClipboardCheck,
  BIconQuestionCircleFill,
  BIconCheckSquare,
  BIconQuestionSquare,
  BIconPlusSquare,
  BIconFileEarmarkMinus} from 'bootstrap-vue'

import 'bootstrap/dist/css/bootstrap.css'
import 'bootstrap-vue/dist/bootstrap-vue.css'

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
Vue.component("BIconPersonCircle", BIconPersonCircle)
Vue.component("BIconStoplights", BIconStoplights)
Vue.component("BIconFilter", BIconFilter)
Vue.component("BIconSearch", BIconSearch)
Vue.component("BIconCheck", BIconCheck)
Vue.component("BIconX", BIconX)
Vue.component("BIconXCircle", BIconXCircle)
Vue.component("BIconArrowRepeat", BIconArrowRepeat)
Vue.component("BIconEye", BIconEye)
Vue.component("BIconEyeSlash", BIconEyeSlash)
Vue.component("BIconPen", BIconPen)
Vue.component("BIconCheck2Circle", BIconCheck2Circle)
Vue.component("BIconHandThumbsUp", BIconHandThumbsUp)
Vue.component("BIconHandThumbsDown", BIconHandThumbsDown)
Vue.component("BIconBoxArrowUpRight", BIconBoxArrowUpRight)
Vue.component("BIconTable", BIconTable)
Vue.component("BIconDownload", BIconDownload)
Vue.component("BIconClipboardCheck", BIconClipboardCheck)
Vue.component("BIconQuestionCircleFill", BIconQuestionCircleFill)
Vue.component("BIconCheckSquare", BIconCheckSquare)
Vue.component("BIconQuestionSquare", BIconQuestionSquare)
Vue.component("BIconPlusSquare", BIconPlusSquare)
Vue.component("BIconFileEarmarkMinus", BIconFileEarmarkMinus)

// register vue-meta globally
Vue.use(VueMeta, {
  keyName: 'metaInfo',
  attribute: 'data-vue-meta',
  ssrAttribute: 'data-vue-meta-server-rendered',
  tagIDKeyName: 'vmid',
  refreshOnceOnNavigation: true
})


// Install VeeValidate rules and localization (based on https://codesandbox.io/s/boostrapvue-veevalidate-v3-example-xm3et?from-embed=&file=/index.js)
Object.keys(rules).forEach(rule => {
  extend(rule, rules[rule]);
});

localize("en", en);

// Install VeeValidate components globally
Vue.component("ValidationObserver", ValidationObserver)
Vue.component("ValidationProvider", ValidationProvider)

new Vue({
  router,
  render: h => h(App)
}).$mount('#app')

