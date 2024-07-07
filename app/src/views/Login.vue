<!-- src/views/Login.vue -->
<template>
  <div class="container-fluid">
    <!-- Loading Spinner -->
    <b-spinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />

    <!-- Login Form -->
    <b-container v-else>
      <b-row class="justify-content-md-center py-4">
        <b-col md="6">
          <b-card
            header="Sign in"
            header-bg-variant="dark"
            header-text-variant="white"
          >
            <b-card-text>
              <validation-observer
                ref="observer"
                v-slot="{ handleSubmit }"
              >
                <b-form @submit.stop.prevent="handleSubmit(onSubmit)">
                  <!-- Username Field -->
                  <validation-provider
                    v-slot="{ errors, validated, dirty }"
                    name="username"
                    :rules="{ required: true, min: 5, max: 20 }"
                  >
                    <b-form-group description="Enter your user name">
                      <b-form-input
                        v-model="user_name"
                        placeholder="User"
                        :state="getValidationState({ errors, validated, dirty })"
                      />
                      <b-form-invalid-feedback v-if="errors.length">
                        {{ errors[0] }}
                      </b-form-invalid-feedback>
                    </b-form-group>
                  </validation-provider>

                  <!-- Password Field -->
                  <validation-provider
                    v-slot="{ errors, validated, dirty }"
                    name="password"
                    :rules="{ required: true, min: 5, max: 50 }"
                  >
                    <b-form-group description="Enter your user password">
                      <b-form-input
                        v-model="password"
                        placeholder="Password"
                        type="password"
                        :state="getValidationState({ errors, validated, dirty })"
                      />
                      <b-form-invalid-feedback v-if="errors.length">
                        {{ errors[0] }}
                      </b-form-invalid-feedback>
                    </b-form-group>
                  </validation-provider>

                  <!-- Form Buttons -->
                  <b-form-group>
                    <b-button
                      class="ml-2"
                      variant="outline-dark"
                      @click="resetForm"
                    >
                      Reset
                    </b-button>
                    <b-button
                      class="ml-2"
                      :class="{ shake: animated }"
                      type="submit"
                      variant="dark"
                    >
                      Login
                    </b-button>
                  </b-form-group>
                </b-form>
              </validation-observer>

              <!-- Additional Links -->
              <div>
                Don't have an account yet and want to help?
                <b-link :href="'/Register'">
                  Register now.
                </b-link>
              </div>
              <div>
                Forgot your password?
                <b-link :href="'/PasswordReset'">
                  Reset now.
                </b-link>
              </div>
            </b-card-text>
          </b-card>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import { ValidationObserver, ValidationProvider } from 'vee-validate';
import toastMixin from '@/assets/js/mixins/toastMixin';

export default {
  name: 'Login',
  components: {
    ValidationObserver,
    ValidationProvider,
  },
  mixins: [toastMixin],
  metaInfo: {
    title: 'Login',
    titleTemplate:
      '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: { lang: 'en' },
    meta: [
      {
        vmid: 'description',
        name: 'description',
        content: 'The Login view allows users and curators to log into their SysNDD account.',
      },
    ],
  },
  data() {
    return {
      user_name: '',
      password: '',
      loading: true,
      animated: false,
    };
  },
  mounted() {
    if (localStorage.user) {
      this.doUserLogOut();
    }
    this.loading = false;
  },
  methods: {
    getValidationState({ errors, dirty, validated }) {
      if (errors.length) {
        return false;
      }
      return dirty || validated ? true : null;
    },
    async loadJWT() {
      const apiAuthenticateURL = `${process.env.VUE_APP_API_URL}/api/auth/authenticate?user_name=${this.user_name}&password=${this.password}`;
      try {
        const response_authenticate = await this.axios.get(apiAuthenticateURL);
        localStorage.setItem('token', response_authenticate.data[0]);
        this.makeToast(`You have logged in (status ${response_authenticate.status} - ${response_authenticate.statusText}).`, 'Success', 'success');
        this.signinWithJWT();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async signinWithJWT() {
      const apiAuthenticateURL = `${process.env.VUE_APP_API_URL}/api/auth/signin`;
      try {
        const response_signin = await this.axios.get(apiAuthenticateURL, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.user = response_signin.data;
        localStorage.setItem('user', JSON.stringify(response_signin.data));
        this.$router.push('/');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
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
      this.animated = true;
      setTimeout(() => {
        this.animated = false;
      }, 1000);
    },
  },
};
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
  color: #0502a0;
}

.shake {
  animation: shake 0.82s cubic-bezier(0.36, 0.07, 0.19, 0.97) both;
  transform: translate3d(0, 0, 0);
}
@keyframes shake {
  10%,
  90% {
    transform: translate3d(-1px, 0, 0);
  }
  20%,
  80% {
    transform: translate3d(2px, 0, 0);
  }
  30%,
  50%,
  70% {
    transform: translate3d(-4px, 0, 0);
  }
  40%,
  60% {
    transform: translate3d(4px, 0, 0);
  }
}
</style>

  <!-- based on https://www.youtube.com/watch?v=d9qfI0ESlzY&ab_channel=JakeHarrisCodes -->
