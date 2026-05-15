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
</style>
