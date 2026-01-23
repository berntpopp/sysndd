import Vue, { createApp, configureCompat } from 'vue';
import { createHead } from '@unhead/vue/client';
import { createPinia } from 'pinia';

// import custom js
import './assets/js/functions';

// import global components
import './global-components';

// Bootstrap-Vue (uses @vue/compat for Vue 3 compatibility)
// Keep during transition - existing components still use these
import { BootstrapVue, BootstrapVueIcons, ToastPlugin } from 'bootstrap-vue';

// Bootstrap-Vue-Next (Vue 3 native Bootstrap 5 components)
import { createBootstrap } from 'bootstrap-vue-next';

// Bootstrap 5 CSS (required by Bootstrap-Vue-Next)
import 'bootstrap/dist/css/bootstrap.css';
// Bootstrap-Vue-Next CSS
import 'bootstrap-vue-next/dist/bootstrap-vue-next.css';
// Bootstrap-Vue CSS (keep during transition for existing components)
import 'bootstrap-vue/dist/bootstrap-vue.css';

// Custom SCSS overrides (loads after bootstrap)
import './assets/scss/custom.scss';

// import axios
import VueAxios from 'vue-axios';
import axios from 'axios';

import App from './App.vue';

// import router
import router from './router';
import './registerServiceWorker';

// import custom css
import './assets/css/custom.css';

// Configure @vue/compat runtime behavior
// MODE: 2 enables full Vue 2 compatibility
// Enable specific compat features needed by bootstrap-vue
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

Vue.component('Navbar', require('./components/Navbar.vue').default);

Vue.use(VueAxios, axios);

// Create Vue 3 app instance
const pinia = createPinia();
const head = createHead();
const app = createApp(App);

// Register axios on Vue 3 app instance (VueAxios via Vue.use doesn't fully transfer)
app.config.globalProperties.axios = axios;
app.config.globalProperties.$http = axios;

// Register Bootstrap-Vue-Next plugin (Vue 3 native)
app.use(createBootstrap());

// Register @unhead/vue for head management
app.use(head);

app.use(pinia);
app.use(router);
app.mount('#app');
