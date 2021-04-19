<template>
  <div style="padding-top: 80px;">
    <h1>sysndd_id {{ $route.params.sysndd_id }}</h1>
    <button v-on:click="loadEntity">test</button>
  </div>
</template>

<script>
export default {
  name: 'Entity',
  methods: {
    async loadEntity() {
      let apiURL = 'http://127.0.0.1:7777/api/entities/' + this.$route.params.sysndd_id;
      let response = await this.axios.get(apiURL);
      console.log(response);
    }
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
h3 {
  margin: 40px 0 0;
}
ul {
  list-style-type: none;
  padding: 0;
}
li {
  display: inline-block;
  margin: 0 10px;
}
a {
  color: #42b983;
}
</style>
