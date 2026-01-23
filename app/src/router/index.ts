import { createRouter, createWebHistory } from 'vue-router';
import { routes } from './routes';

// Support both Vite (import.meta.env) and Vue CLI (process.env) during migration
// eslint-disable-next-line no-undef
const baseUrl = typeof import.meta !== 'undefined' ? import.meta.env.BASE_URL : process.env.BASE_URL;

const router = createRouter({
  history: createWebHistory(baseUrl),
  routes,
});

export default router;
