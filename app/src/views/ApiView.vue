<template>
  <div class="container-fluid text-start py-2">
    <div
      v-if="error"
      class="alert alert-warning"
    >
      {{ error }}
    </div>
    <div
      v-if="loading"
      class="text-center py-4"
    >
      Loading API documentation...
    </div>
    <div
      id="swagger-ui"
      class="swagger"
    />
  </div>
</template>

<script>
export default {
  name: 'ApiView',
  data() {
    return {
      error: null,
      loading: true,
    };
  },
  mounted() {
    this.loadSwaggerUI();
  },
  methods: {
    loadSwaggerUI() {
      // Load Swagger UI CSS
      const cssLink = document.createElement('link');
      cssLink.rel = 'stylesheet';
      cssLink.href = 'https://unpkg.com/swagger-ui-dist@5.31.0/swagger-ui.css';
      document.head.appendChild(cssLink);

      // Load Swagger UI Bundle
      const script = document.createElement('script');
      script.src = 'https://unpkg.com/swagger-ui-dist@5.31.0/swagger-ui-bundle.js';
      script.onload = () => {
        this.initSwagger();
      };
      script.onerror = () => {
        this.error = 'Failed to load API documentation. Please try refreshing the page.';
        this.loading = false;
      };
      document.head.appendChild(script);
    },
    initSwagger() {
      try {
        const apiURL = `${import.meta.env.VITE_API_URL}/api/admin/openapi.json`;
         
        SwaggerUIBundle({
          dom_id: '#swagger-ui',
          url: apiURL,
          docExpansion: 'none',
          presets: [
             
            SwaggerUIBundle.presets.apis,
          ],
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
