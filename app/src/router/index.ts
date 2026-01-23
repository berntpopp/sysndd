import { createRouter, createWebHistory } from 'vue-router';
import type { Router } from 'vue-router';
import { routes } from './routes';

// Support both Vite (import.meta.env) and Vue CLI (process.env) during migration
const baseUrl: string = import.meta.env.BASE_URL;

const router: Router = createRouter({
  history: createWebHistory(baseUrl),
  routes,
});

export default router;
