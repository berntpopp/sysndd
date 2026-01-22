import Vue, { createApp, configureCompat } from 'vue';
import VueMeta from 'vue-meta';
import { createPinia } from 'pinia';

// import custom js
import './assets/js/functions';

// import global components
import './global-components';

// Bootstrap-Vue (uses @vue/compat for Vue 3 compatibility)
import { BootstrapVue, BootstrapVueIcons, ToastPlugin } from 'bootstrap-vue';

// Bootstrap 4 CSS (Bootstrap-Vue requires Bootstrap 4)
import 'bootstrap/dist/css/bootstrap.css';
import 'bootstrap-vue/dist/bootstrap-vue.css';

// Custom SCSS overrides (loads after bootstrap)
import './assets/scss/custom.scss';

// import axios
import VueAxios from 'vue-axios';
import axios from 'axios';

// vee-validate imports
import {
  ValidationObserver,
  ValidationProvider,
  extend,
  localize,
} from 'vee-validate';

import en from 'vee-validate/dist/locale/en.json';
import * as rules from 'vee-validate/dist/rules';

// import perfect-scrollbar
import PerfectScrollbar from 'vue2-perfect-scrollbar';
import 'vue2-perfect-scrollbar/dist/vue2-perfect-scrollbar.css';

// eslint: import should occur after import of `vee-validate/dist/rules`
import App from './App.vue';

// import router
import router from './router';
import './registerServiceWorker';

// import custom css
import './assets/css/custom.css';

// Configure @vue/compat runtime behavior
// MODE: 2 enables full Vue 2 compatibility
// Enable specific compat features needed by vue-meta and bootstrap-vue
configureCompat({
  MODE: 2,
  INSTANCE_CHILDREN: true,
  INSTANCE_LISTENERS: true,
  INSTANCE_EVENT_EMITTER: true,
  INSTANCE_EVENT_HOOKS: true,
  OPTIONS_BEFORE_DESTROY: true,
  OPTIONS_DESTROYED: true,
  COMPONENT_ASYNC: true,
  GLOBAL_PROTOTYPE: true,
  GLOBAL_EXTEND: true,
  GLOBAL_MOUNT: true,
  RENDER_FUNCTION: true,
  WATCH_ARRAY: true,
  ATTR_FALSE_VALUE: true,
});

// Install Bootstrap-Vue globally (Vue 2 style, handled by @vue/compat)
Vue.use(BootstrapVue);
Vue.use(BootstrapVueIcons);
Vue.use(ToastPlugin);

Vue.use(PerfectScrollbar);

Vue.component('Navbar', require('./components/Navbar.vue').default);

Vue.use(VueAxios, axios);

// register vue-meta globally
Vue.use(VueMeta, {
  keyName: 'metaInfo',
  attribute: 'data-vue-meta',
  ssrAttribute: 'data-vue-meta-server-rendered',
  tagIDKeyName: 'vmid',
  refreshOnceOnNavigation: true,
});

// Install VeeValidate rules and localization
Object.keys(rules).forEach((rule) => {
  extend(rule, rules[rule]);
});

localize('en', en);

// Install VeeValidate components globally
Vue.component('ValidationObserver', ValidationObserver);
Vue.component('ValidationProvider', ValidationProvider);

// Create Vue 3 app instance
const pinia = createPinia();
const app = createApp(App);

app.use(pinia);
app.use(router);
app.mount('#app');
