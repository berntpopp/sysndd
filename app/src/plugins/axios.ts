import axios from 'axios';
import router from '@/router';

// Configure axios defaults
axios.defaults.baseURL = import.meta.env.VITE_BASE_URL || '';
axios.defaults.headers.common.Authorization = `Bearer ${localStorage.getItem('token')}`;

// Guard flag to prevent duplicate 401 redirects
let isLoggingOut = false;

// Response interceptor: centralized 401 handling
axios.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 && !isLoggingOut) {
      isLoggingOut = true;

      // Clear auth state
      localStorage.removeItem('token');
      localStorage.removeItem('user');

      // Redirect to login with return path
      const currentPath = router.currentRoute.value.fullPath;
      router.push({
        path: '/Login',
        query: currentPath !== '/' ? { redirect: currentPath } : undefined,
      });

      // Reset guard after a window to coalesce concurrent 401s
      setTimeout(() => {
        isLoggingOut = false;
      }, 2000);

      // Return a never-resolving promise to suppress downstream .catch() toasts
      return new Promise(() => {});
    }

    return Promise.reject(error);
  }
);

export default axios;
