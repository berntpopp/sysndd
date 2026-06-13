<template>
  <div class="container-fluid text-start py-2">
    <div v-if="error" class="alert alert-warning">
      {{ error }}
    </div>
    <div v-if="loading" class="text-center py-4">Loading API documentation...</div>
    <div id="swagger-ui" class="swagger" />
  </div>
</template>

<script>
import SwaggerUIBundle from 'swagger-ui-dist/swagger-ui-es-bundle.js';
import 'swagger-ui-dist/swagger-ui.css';

export default {
  name: 'ApiView',
  data() {
    return {
      error: null,
      loading: true,
    };
  },
  mounted() {
    this.initSwagger();
  },
  methods: {
    initSwagger() {
      try {
        const apiBaseUrl = import.meta.env.VITE_API_URL ?? '';
        const apiURL = `${apiBaseUrl}/api/admin/openapi.json`;

        SwaggerUIBundle({
          dom_id: '#swagger-ui',
          url: apiURL,
          docExpansion: 'none',
          presets: [SwaggerUIBundle.presets.apis],
        });
        this.loading = false;
      } catch (err) {
        console.error('Failed to initialize Swagger UI:', err);
        this.error = 'Failed to load API documentation. Please try refreshing the page.';
        this.loading = false;
      }
    },
  },
};
</script>

<style scoped>
:deep(.version) {
  color: #000 !important;
}

/* Fix Swagger UI HTTP-method badge contrast (WCAG AA).
   Swagger uses bright pastel backgrounds (#49cc90, #61affe, #fca130, #f93e3e, #50e3c2)
   with white text — all fail 4.5:1. Dark text on those backgrounds passes easily:
   black (#000) on #49cc90 ≈ 14:1, on #61affe ≈ 7:1, on #fca130 ≈ 11:1,
   on #f93e3e ≈ 6:1, on #50e3c2 ≈ 12:1. All ≥ 4.5:1 ✓ AA. */
:deep(.opblock-summary-method) {
  color: #000 !important;
  text-shadow: none !important;
}
</style>
