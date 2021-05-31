<template>
  <div>
    <b-navbar fixed="top" toggleable="lg" type="dark" variant="dark">
      <b-navbar-brand href="/"><img src="../../public/android-chrome-192x192.png" height="40" alt=""> SysNDD</b-navbar-brand>

      <b-navbar-toggle target="nav-collapse"></b-navbar-toggle>

      <b-collapse id="nav-collapse" is-nav>
        <b-navbar-nav>
          <b-nav-item href="/Entities">Entities</b-nav-item>
          <b-nav-item href="/Genes">Genes</b-nav-item>
          <b-nav-item href="/Phenotypes">Phenotypes</b-nav-item>
          <b-nav-item href="/Panels">Panels</b-nav-item>
          <b-nav-item href="/Comparisons">Comparisons</b-nav-item>
          <b-nav-item href="/About">About</b-nav-item>
        </b-navbar-nav>

        <!-- Right aligned nav items -->
        <b-navbar-nav class="ml-auto">
      
          <b-nav-item v-if="user" href="/Review">Review</b-nav-item>
          
          <b-nav-item-dropdown right v-if="user">
            <!-- Using 'button-content' slot -->
            <template #button-content>
              <em>{{ user }}</em>
            </template>
            <b-dropdown-item href="/User">Profile</b-dropdown-item>
            <b-dropdown-item @click="duUserLogOut">Sign Out</b-dropdown-item>
          </b-nav-item-dropdown>
          <b-nav-item href="/Login" v-else>Login</b-nav-item>

        </b-navbar-nav>
      </b-collapse>
    </b-navbar>
  </div>
</template>

<script>
export default {
  name: 'Navbar',
  data() {
        return {
          user: null
        }
  },
  watch: { // used to refreh navar on login push
  $route(to, from) { 
    if(to !== from){ 
      location.reload(); 
      }
  } 
  },
  mounted() {
    this.isUserLoggedIn();
    },
  methods: {
    isUserLoggedIn() {
      if (localStorage.user) {
        this.user = JSON.parse(localStorage.user).user_name[0];
      }
    },
    duUserLogOut() {
      if (localStorage.user) {
        localStorage.removeItem('user');
        this.user = null;
        this.$router.push('/');
      }
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
