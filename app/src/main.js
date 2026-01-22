import Vue, { createApp } from 'vue';
import VueMeta from 'vue-meta';

import { createPinia } from 'pinia';

// import custom js
import './assets/js/functions';

// import global components
import './global-components';

// import b-vue icons
import {
  BIconPersonCircle,
  BIconEmojiSmile,
  BIconEmojiHeartEyes,
  BIconEmojiSunglasses,
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
  BIconClipboardPlus,
  BIconQuestionCircleFill,
  BIconCheckSquare,
  BIconQuestionSquare,
  BIconPlusSquare,
  BIconFileEarmarkMinus,
  BIconLink,
  BIconGear,
  BIconExclamationTriangle,
  BIconBookFill,
  BIconExclamationTriangleFill,
  BIconChatLeftQuoteFill,
  BIconListNested,
  BIconBarChartLine,
  BIconImage,
  BIconFileEarmark,
  ToastPlugin,
} from 'bootstrap-vue';

// based on https://stackoverflow.com/questions/54829710/how-to-override-bootstrap-variables-in-vue-workflow-vanilla-bootstrap
// import 'bootstrap/dist/css/bootstrap.css'

import './assets/scss/custom.scss';
import 'bootstrap-vue/dist/bootstrap-vue.css';

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

Vue.use(PerfectScrollbar);

Vue.component('Navbar', require('./components/Navbar.vue').default);

Vue.use(VueAxios, axios);
Vue.use(ToastPlugin);

// Install the BootstrapVue icon components plugin
Vue.component('BIconPersonCircle', BIconPersonCircle);
Vue.component('BIconEmojiSmile', BIconEmojiSmile);
Vue.component('BIconEmojiHeartEyes', BIconEmojiHeartEyes);
Vue.component('BIconEmojiSunglasses', BIconEmojiSunglasses);
Vue.component('BIconStoplights', BIconStoplights);
Vue.component('BIconFilter', BIconFilter);
Vue.component('BIconSearch', BIconSearch);
Vue.component('BIconCheck', BIconCheck);
Vue.component('BIconX', BIconX);
Vue.component('BIconXCircle', BIconXCircle);
Vue.component('BIconArrowRepeat', BIconArrowRepeat);
Vue.component('BIconEye', BIconEye);
Vue.component('BIconEyeSlash', BIconEyeSlash);
Vue.component('BIconPen', BIconPen);
Vue.component('BIconCheck2Circle', BIconCheck2Circle);
Vue.component('BIconHandThumbsUp', BIconHandThumbsUp);
Vue.component('BIconHandThumbsDown', BIconHandThumbsDown);
Vue.component('BIconBoxArrowUpRight', BIconBoxArrowUpRight);
Vue.component('BIconTable', BIconTable);
Vue.component('BIconDownload', BIconDownload);
Vue.component('BIconClipboardCheck', BIconClipboardCheck);
Vue.component('BIconClipboardPlus', BIconClipboardPlus);
Vue.component('BIconQuestionCircleFill', BIconQuestionCircleFill);
Vue.component('BIconCheckSquare', BIconCheckSquare);
Vue.component('BIconQuestionSquare', BIconQuestionSquare);
Vue.component('BIconPlusSquare', BIconPlusSquare);
Vue.component('BIconFileEarmarkMinus', BIconFileEarmarkMinus);
Vue.component('BIconLink', BIconLink);
Vue.component('BIconGear', BIconGear);
Vue.component('BIconExclamationTriangle', BIconExclamationTriangle);
Vue.component('BIconBookFill', BIconBookFill);
Vue.component('BIconExclamationTriangleFill', BIconExclamationTriangleFill);
Vue.component('BIconChatLeftQuoteFill', BIconChatLeftQuoteFill);
Vue.component('BIconListNested', BIconListNested);
Vue.component('BIconBarChartLine', BIconBarChartLine);
Vue.component('BIconImage', BIconImage);
Vue.component('BIconFileEarmark', BIconFileEarmark);

// register vue-meta globally
Vue.use(VueMeta, {
  keyName: 'metaInfo',
  attribute: 'data-vue-meta',
  ssrAttribute: 'data-vue-meta-server-rendered',
  tagIDKeyName: 'vmid',
  refreshOnceOnNavigation: true,
});

// Install VeeValidate rules and localization (based on https://codesandbox.io/s/boostrapvue-veevalidate-v3-example-xm3et?from-embed=&file=/index.js)
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
