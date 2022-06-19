<template>
  <div class="container-fluid text-left py-2">
    <div
      id="swagger"
      class="swagger"
    />
  </div>
</template>

<script>
import SwaggerUI from "swagger-ui";
import "swagger-ui/dist/swagger-ui.css";

export default {
  name: "Swagger",
  mounted() {
    this.loadAPIInfo();
  },
  methods: {
    async loadAPIInfo() {
      let apiURL = process.env.VUE_APP_API_URL + "/openapi.json";
      SwaggerUI({
        dom_id: "#swagger",
        url: apiURL,
        docExpansion: "none",
      });
    },
  },
};
</script>

<style scoped>
</style> 