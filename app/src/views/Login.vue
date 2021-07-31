<template>
  <div class="container-fluid" style="min-height:90vh">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>

    <b-container v-else>
      <b-row class="justify-content-md-center py-4">
        <b-col md="6">
          <b-card
          header="Sign in"
          header-bg-variant="dark"
          header-text-variant="white"
          >
          <b-card-text>

            <b-form @submit="onSubmit">
              <b-form-group
                description="Enter your user name"
              >
                <b-form-input
                  v-model="user_name"
                  placeholder="User"
                  required
                ></b-form-input>
              </b-form-group>

              <b-form-group
                description="Enter your user password"
              >
                <b-form-input
                  v-model="password"
                  placeholder="Password"
                  required
                  type="password"
                ></b-form-input>

              </b-form-group>

              <b-form-group>
                <b-button type="submit" variant="outline-dark">Login</b-button>
              </b-form-group>
              </b-form>
            
            </b-card-text>  
            </b-card>
          </b-col>
        </b-row>
      </b-container>

  </div>
</template>

<script>
export default {
  name: 'Login',
  data() {
      return {
        user_name: '',
        password: '',
        ywt: '',
        user: [],
        loading: true
      }
    },
  mounted() {
    if (localStorage.user) {
      this.doUserLogOut();
    }
    this.loading = false;
  },
  methods: {
    async loadJWT() {
      let apiAuthenticateURL = process.env.VUE_APP_API_URL + '/api/auth/authenticate?user_name=' + this.user_name + '&password=' + this.password;
      try {
        let response_authenticate = await this.axios.get(apiAuthenticateURL);
        localStorage.setItem('token', response_authenticate.data[0]);
        this.makeToast('You have logged in  ' + '(status ' + response_authenticate.status + ' (' + response_authenticate.statusText + ').', 'Success', 'success');
        this.signinWithJWT();
        } catch (e) {
        console.error(e.response.status);
         this.makeToast(e, 'Error', 'success');
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

        this.user = response_signin.data;
        localStorage.setItem('user', JSON.stringify(response_signin.data));
        this.$router.push('/');

        } catch (e) {
        console.error(e);
        }
    }, 
    onSubmit(event) {
      event.preventDefault();
      this.loadJWT();
    },
    doUserLogOut() {
      if (localStorage.user || localStorage.token) {
        localStorage.removeItem('user');
        localStorage.removeItem('token');
        this.user = null;
        this.$router.push('/');
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

  <!-- basesd on https://www.youtube.com/watch?v=d9qfI0ESlzY&ab_channel=JakeHarrisCodes -->