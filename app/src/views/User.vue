<template>
  <div class="container-fluid">
    <b-container>
        <h2>User: {{ this.user.user_name }}</h2>
        <h2>ID: {{ this.user.user_id }}</h2>
        <h2>Role: {{ this.user.user_role }}</h2>
        <h2>Expires: {{ this.user.exp }}</h2>
    </b-container>
  </div>
</template>

<script>
export default {
  name: 'User',
  data() {
        return {
          user: []
        }
  },
  mounted() {
    if (localStorage.user) {
      this.user = JSON.parse(localStorage.user);
    }
  },
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