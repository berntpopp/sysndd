<template>
  <div>
    <b-navbar toggleable="md" type="dark" variant="dark" class="py-0">
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
          <b-nav-item v-if="user && review" href="/Review">Re-Review</b-nav-item>
          
          <b-nav-item-dropdown right v-if="user">
            <!-- Using 'button-content' slot -->
            <template #button-content>
              <em>{{ user }}</em>
            </template>
            <b-dropdown-item href="/User"><b-icon icon="person-circle" font-scale="1.0"></b-icon> View profile</b-dropdown-item>
            <b-dropdown-item @click="refreshWithJWT"><b-icon icon="arrow-repeat" font-scale="1.0"></b-icon> Refresh token <b-badge variant="info">{{ Math.floor(this.time_to_logout) }} m {{ ((this.time_to_logout - Math.floor(this.time_to_logout)) * 60).toFixed(0) }} s</b-badge></b-dropdown-item>
            <b-dropdown-item @click="doUserLogOut"><b-icon icon="x-circle" font-scale="1.0"></b-icon> Sign out </b-dropdown-item>
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
          user_from_jwt: [],
          time_to_logout: 0
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

    this.interval = setInterval(() => {
      this.updateDiffs();
    },1000);
    this.updateDiffs();

    },
  methods: {
    isUserLoggedIn() {
      if (localStorage.user && localStorage.token) {
        this.checkSigninWithJWT();
      } else {
        localStorage.removeItem('user');
        localStorage.removeItem('token');
      }
    },
    async checkSigninWithJWT() {
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
    async refreshWithJWT() {
      let apiAuthenticateURL = process.env.VUE_APP_API_URL + '/api/auth/refresh';

      try {
        let response_refresh = await this.axios.get(apiAuthenticateURL, {
        headers: {
          'Authorization': 'Bearer ' + localStorage.getItem('token')
        }
        });
  
        localStorage.setItem('token', response_refresh.data[0]);
        this.signinWithJWT();

        } catch (e) {
        console.error(e);
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

        localStorage.setItem('user', JSON.stringify(response_signin.data));

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
    },
    updateDiffs() {
      if (localStorage.token) {
        let expires = JSON.parse(localStorage.user).exp;
        let timestamp = Math.floor(new Date().getTime() / 1000);

        if (expires > timestamp) {
          this.time_to_logout = ((expires - timestamp) / 60).toFixed(2);
          if ( [60, 180, 300].includes(expires - timestamp)) {
          this.makeToast('Refresh token.', 'Logout in ' + (expires - timestamp) + ' seconds', 'danger');
          }
        } else {
          this.doUserLogOut();
        }
      }
    },
    makeToast(event, title = null, variant = null) {
        this.$bvToast.toast('' + event, {
          title: title,
          toaster: 'b-toaster-top-right',
          variant: variant,
          solid: true
        })
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
