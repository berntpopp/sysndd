<template>
  <div class="container-fluid" style="min-height:90vh">
    <div class="swagger" id="swagger">
    </div>
  </div>
</template>

<script>
import SwaggerUI from 'swagger-ui';
import 'swagger-ui/dist/swagger-ui.css';

export default {
    name: "Swagger",
    mounted() {
      this.loadAPIInfo();
    },
  methods: {
  async loadAPIInfo() {
        let apiURL = process.env.VUE_APP_API_URL + '/openapi.json';

        SwaggerUI({
            dom_id: '#swagger',
            url: apiURL,
            docExpansion: 'none'
        })
    }
  }
}
</script>

<style scoped>
.btn-group-xs > .btn, .btn-xs {
  padding: .25rem .4rem;
  font-size: .875rem;
  line-height: .5;
  border-radius: .2rem;
}
</style>