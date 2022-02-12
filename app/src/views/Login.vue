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

            <validation-observer ref="observer" v-slot="{ handleSubmit }">

              <b-form @submit.stop.prevent="handleSubmit(onSubmit)">

                <validation-provider
                  name="username"
                  :rules="{ required: true, min: 5, max: 20 }"
                  v-slot="validationContext"
                >
                  <b-form-group
                    description="Enter your user name"
                  >
                    <b-form-input
                      v-model="user_name"
                      placeholder="User"
                      :state="getValidationState(validationContext)"
                    ></b-form-input>
                  </b-form-group>
                </validation-provider>

                <validation-provider 
                  name="password" 
                  :rules="{ required: true, min: 5, max: 50 }" 
                  v-slot="validationContext"
                >
                  <b-form-group
                    description="Enter your user password"
                  >
                    <b-form-input
                      v-model="password"
                      placeholder="Password"
                      type="password"
                      :state="getValidationState(validationContext)"
                    ></b-form-input>

                  </b-form-group>
                </validation-provider>

                <b-form-group>
                  <b-button class="ml-2" @click="resetForm()" variant="outline-dark">Reset</b-button>
                  <b-button class="ml-2" :class="{'shake' : animated}" @click="clickHandler()" type="submit" variant="dark">Login</b-button>
                </b-form-group>
                </b-form>

              </validation-observer>

              Don't have an account yet and want to help? <b-link v-bind:href="'/Register'">Register now.</b-link> <br />
              Forgot your password? <b-link v-bind:href="'/PasswordReset'">Reset now.</b-link>
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
        loading: true,
        animated: false
      }
    },
  mounted() {
    if (localStorage.user) {
      this.doUserLogOut();
    }
    this.loading = false;
  },
  methods: {
    getValidationState({ dirty, validated, valid = null }) {
      return dirty || validated ? valid : null;
    },
    async loadJWT() {
      let apiAuthenticateURL = process.env.VUE_APP_API_URL + '/api/auth/authenticate?user_name=' + this.user_name + '&password=' + this.password;
      try {
        let response_authenticate = await this.axios.get(apiAuthenticateURL);
        localStorage.setItem('token', response_authenticate.data[0]);
        this.makeToast('You have logged in  ' + '(status ' + response_authenticate.status + ' (' + response_authenticate.statusText + ').', 'Success', 'success');
        this.signinWithJWT();
        } catch (e) {
          console.error(e.response.status);
          this.makeToast(e, 'Error', 'danger');
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
    resetForm() {
      this.user_name = '';
      this.password = '';

      this.$nextTick(() => {
        this.$refs.observer.reset();
      });
    },
    onSubmit(event) {
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
    clickHandler() {
      const self = this
      self.animated = true
      setTimeout(() => {
        self.animated = false
      }, 1000)
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
<!-- Shake based on https://codepen.io/aut0maat10/pen/ExaNZNo -->
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
  color: #0502A0;
}

.shake {
  animation: shake 0.82s cubic-bezier(.36,.07,.19,.97) both;
  transform: translate3d(0, 0, 0);
}
@keyframes shake {
  10%, 90% {
    transform: translate3d(-1px, 0, 0);
  }
  20%, 80% {
    transform: translate3d(2px, 0, 0);
  }
  30%, 50%, 70% {
    transform: translate3d(-4px, 0, 0);
  }
  40%, 60% {
    transform: translate3d(4px, 0, 0);
  }
}
</style>

  <!-- basesd on https://www.youtube.com/watch?v=d9qfI0ESlzY&ab_channel=JakeHarrisCodes -->