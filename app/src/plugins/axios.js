import Vue from 'vue';
import axios from 'axios';

// Full config:  https://github.com/axios/axios#request-config
axios.defaults.baseURL = import.meta.env.VITE_BASE_URL || '';
axios.defaults.headers.common.Authorization = `Bearer ${localStorage.getItem('token')}`;
// axios.defaults.headers.post['Content-Type'] = 'application/x-www-form-urlencoded';

const config = {
  // baseURL: process.env.baseURL || process.env.apiUrl || ""
  // timeout: 60 * 1000, // Timeout
  // withCredentials: true, // Check cross-site Access-Control
};

const _axios = axios.create(config);

_axios.interceptors.request.use(
  (config) => config,
  (error) => Promise.reject(error),

);

// Add a response interceptor
_axios.interceptors.response.use(
  (response) => response,
  (error) => Promise.reject(error),

);

const plugin = function install(Vue, options) {
  Vue.axios = _axios;
  window.axios = _axios;
  Object.defineProperties(Vue.prototype, {
    axios: {
      get() {
        return _axios;
      },
    },
    $axios: {
      get() {
        return _axios;
      },
    },
  });
};

Vue.use(plugin);

export default plugin;
