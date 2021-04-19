<template>
  <div class="container-fluid" style="padding-top: 80px;">
      <mdb-datatable color="black" textWhite
        :data="'http://127.0.0.1:7777/api/entities'"
        hover
        :display="5"
        :tfoot="false"
        small
      />
  </div>
</template>

<script>
import axios from 'axios';
import { mdbDatatable } from 'mdbvue';

export default {
  name: 'Entities',
    components: {
      mdbDatatable
    },
  methods: {
    async loadEntitiesData() {
      let apiUrl = 'http://127.0.0.1:7777/api/entities';
      let response = await this.axios.get(apiUrl);
      return response;
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
