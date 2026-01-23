import { createApp } from 'vue';
import type { App as VueApp, Component } from 'vue';
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

import App from './App.vue';

// import router
import router from './router';
import './registerServiceWorker';

// import custom css
import './assets/css/custom.css';

// Create Vue 3 app instance
const pinia = createPinia();
const head = createHead();
const app: VueApp = createApp(App);

// Register axios on Vue 3 app instance (VueAxios via Vue.use doesn't fully transfer)
app.config.globalProperties.axios = axios;
app.config.globalProperties.$http = axios;
// Also provide axios for composition API inject() usage
app.provide('axios', axios);

// Register Bootstrap-Vue-Next plugin (Vue 3 native)
app.use(createBootstrap());

// Register Bootstrap-Vue-Next directives globally
app.directive('b-tooltip', vBTooltip);
app.directive('b-toggle', vBToggle);

// Register all Bootstrap-Vue-Next components globally
Object.entries(BvnComponents).forEach(([name, component]) => {
  app.component(name, component as Component);
});

// Register @unhead/vue for head management
app.use(head);

app.use(pinia);
app.use(router);
app.mount('#app');
