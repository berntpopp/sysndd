import Vue, { createApp, configureCompat } from 'vue';
import { createHead } from '@unhead/vue/client';
import { createPinia } from 'pinia';

// import custom js
import './assets/js/functions';

// Bootstrap-Vue-Next (Vue 3 native Bootstrap 5 components)
import { createBootstrap, vBTooltip, vBToggle } from 'bootstrap-vue-next';

// Bootstrap 5 CSS (required by Bootstrap-Vue-Next)
import 'bootstrap/dist/css/bootstrap.css';
// Bootstrap-Vue-Next CSS
import 'bootstrap-vue-next/dist/bootstrap-vue-next.css';
// Bootstrap Icons CSS
import 'bootstrap-icons/font/bootstrap-icons.css';

// Custom SCSS overrides (loads after bootstrap)
import './assets/scss/custom.scss';

// import axios
import axios from 'axios';

// Import all Bootstrap-Vue-Next components for global registration
import * as BvnComponents from './bootstrap-vue-next-components';

// Import global async components (will be registered on app instance later)
import globalComponents from './global-components';

import App from './App.vue';

// import router
import router from './router';
import './registerServiceWorker';

// import custom css
import './assets/css/custom.css';

// Configure @vue/compat runtime behavior
// MODE: 2 enables full Vue 2 compatibility as baseline
// Set specific features to false to use Vue 3 behavior (required by Bootstrap-Vue-Next)
configureCompat({
  MODE: 2,
  // Vue 2 compat features still needed by legacy code
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
  // Use Vue 3 behavior for these features (required by Bootstrap-Vue-Next)
  // ATTR_FALSE_VALUE: false = Vue 3 behavior where false renders as "false" attribute
  ATTR_FALSE_VALUE: false,
  // COMPONENT_V_MODEL: false = Vue 3 v-model using modelValue/update:modelValue
  COMPONENT_V_MODEL: false,
  // INSTANCE_ATTRS_CLASS_STYLE: false = Vue 3 behavior where class/style are in $attrs
  INSTANCE_ATTRS_CLASS_STYLE: false,
  // WATCH_ARRAY: false = Vue 3 behavior requiring deep:true for array mutation watching
  WATCH_ARRAY: false,
  // TRANSITION_GROUP_ROOT: false = Vue 3 behavior where TransitionGroup doesn't render root span
  TRANSITION_GROUP_ROOT: false,
});

// Create Vue 3 app instance
const pinia = createPinia();
const head = createHead();
const app = createApp(App);

// Register axios on Vue 3 app instance (VueAxios via Vue.use doesn't fully transfer)
app.config.globalProperties.axios = axios;
app.config.globalProperties.$http = axios;

// Register Bootstrap-Vue-Next plugin (Vue 3 native)
app.use(createBootstrap());

// Register Bootstrap-Vue-Next directives globally
app.directive('b-tooltip', vBTooltip);
app.directive('b-toggle', vBToggle);

// Register all Bootstrap-Vue-Next components globally
Object.entries(BvnComponents).forEach(([name, component]) => {
  app.component(name, component);
});

// Register all custom global components (async components wrapped with defineAsyncComponent)
Object.entries(globalComponents).forEach(([name, component]) => {
  app.component(name, component);
});

// Register @unhead/vue for head management
app.use(head);

app.use(pinia);
app.use(router);
app.mount('#app');
