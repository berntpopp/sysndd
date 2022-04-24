<template>
  <div>
    <iframe :src="source"></iframe>
  </div>
</template>

<script>

export default {
  name: "Swagger",
  data() {
        return {
          source: process.env.VUE_APP_API_URL + '/__docs__/',
        }
  }
}
</script>

<style scoped>
#app, #app iframe {
  height: 89vh;
  width: 100vw;
  border: none;
  box-sizing: border-box;
}
body {
  margin: 0;
}
</style> 