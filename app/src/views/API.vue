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
      id="swagger"
      class="swagger"
    />
  </div>
</template>

<script>
import 'swagger-ui/dist/swagger-ui.css';

export default {
  name: 'Swagger',
  data() {
    return {
      error: null,
      loading: true,
    };
  },
  mounted() {
    this.loadAPIInfo();
  },
  methods: {
    async loadAPIInfo() {
      try {
        // Dynamic import to avoid bundling issues
        const SwaggerUI = (await import('swagger-ui')).default;
        const apiURL = `${process.env.VUE_APP_API_URL}/api/admin/openapi.json`;
        SwaggerUI({
          dom_id: '#swagger',
          url: apiURL,
          docExpansion: 'none',
        });
        this.loading = false;
      } catch (err) {
        console.error('Failed to load Swagger UI:', err);
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
