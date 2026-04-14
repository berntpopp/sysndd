import axios from 'axios';
import router from '@/router';

// Configure axios defaults
axios.defaults.baseURL = import.meta.env.VITE_BASE_URL || '';

// v11.0 closeout F1: the init-time `localStorage.getItem('token')` →
// `axios.defaults.headers.common.Authorization` seeding has been removed.
// The `apiClient` request interceptor (`@/api/client`) is now the single
// injection point for the Bearer header; it reads `useAuth().token.value`
// on every outbound call, so there is nothing to seed here.

// Guard flag to prevent duplicate 401 redirects
let isLoggingOut = false;

// Response interceptor: centralized 401 handling
axios.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 && !isLoggingOut) {
      isLoggingOut = true;

      // Clear auth state. The localStorage writes remain this plugin's
      // owned responsibility (v11.0 closeout spec §2 goal 1). The
      // `apiClient` request interceptor reads `useAuth().token.value`,
      // which re-reads localStorage via `syncFromStorage()` on every
      // `useAuth()` call, so no axios default header mutation is needed.
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

      // Mark as handled so downstream .catch() can skip toast display,
      // while still rejecting so .finally() cleanup runs properly
      const handled = new Error('Redirecting to login');
      (handled as Error & { __handled401: boolean }).__handled401 = true;
      return Promise.reject(handled);
    }

    return Promise.reject(error);
  }
);

export default axios;
