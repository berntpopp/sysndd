<template>
  <div>
    <b-navbar fixed="top" toggleable="md" type="dark" variant="dark">
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

          <b-nav-item v-if="user && admin" href="/Admin">Admin</b-nav-item>
          <b-nav-item v-if="user && curate" href="/Curate">Curate</b-nav-item>
          <b-nav-item v-if="user && review" href="/Review">Review</b-nav-item>
          
          <b-nav-item-dropdown right v-if="user">
            <!-- Using 'button-content' slot -->
            <template #button-content>
              <em>{{ user }}</em>
            </template>
            <b-dropdown-item href="/User">Profile</b-dropdown-item>
            <b-dropdown-item @click="doUserLogOut">Sign Out</b-dropdown-item>
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
          user: null,
          review: false,
          curate: false,
          admin: false,
          user_from_jwt: []
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
      if (localStorage.user && localStorage.token) {
        this.signinWithJWT();
      } else {
        localStorage.removeItem('user');
        localStorage.removeItem('token');
      }
    },
    async signinWithJWT() {
      let apiAuthenticateURL = process.env.VUE_APP_API_URL + '/api/auth/signin';

      try {
        let response_signin = await this.axios.get(apiAuthenticateURL, {
        headers: {
          'Authorization': 'Bearer ' + localStorage.getItem('token')
        }
        });

        this.user_from_jwt = response_signin.data;

        if (this.user_from_jwt.user_name[0] == JSON.parse(localStorage.user).user_name[0]) {
          const allowed_roles = ["Administrator", "Curator", "Reviewer"];
          const allowence_navigation = [["Admin", "Curate", "Review"], ["Curate", "Review"], ["Review"]];

          this.user = JSON.parse(localStorage.user).user_name[0];

          let user_role = JSON.parse(localStorage.user).user_role[0];
          let allowence = allowence_navigation[allowed_roles.indexOf(user_role)];

          this.review = allowence.includes('Review');
          this.curate = allowence.includes('Curate');
          this.admin = allowence.includes('Admin');
        } else {
          localStorage.removeItem('user');
          localStorage.removeItem('token');
        }

        } catch (e) {
        console.error(e);
        }
    },
    doUserLogOut() {
      if (localStorage.user || localStorage.token) {
        localStorage.removeItem('user');
        localStorage.removeItem('token');
        this.user = null;
        this.$router.push('/Login');
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
