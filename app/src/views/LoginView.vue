<!-- src/views/LoginView.vue -->
<template>
  <div class="container-fluid">
    <!-- Loading Spinner -->
    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />

    <!-- Login Form -->
    <BContainer v-else>
      <BRow class="justify-content-md-center py-4">
        <BCol md="6">
          <BCard header="Sign in" header-bg-variant="dark" header-text-variant="white">
            <BCardText>
              <form @submit.prevent="onSubmit">
                <!-- Username Field -->
                <BFormGroup description="Enter your user name">
                  <BFormInput
                    v-model="user_name"
                    placeholder="User"
                    :state="usernameMeta.touched ? (usernameError ? false : true) : null"
                  />
                  <BFormInvalidFeedback v-if="usernameError">
                    {{ usernameError }}
                  </BFormInvalidFeedback>
                </BFormGroup>

                <!-- Password Field -->
                <BFormGroup description="Enter your user password">
                  <BFormInput
                    v-model="password"
                    placeholder="Password"
                    type="password"
                    :state="passwordMeta.touched ? (passwordError ? false : true) : null"
                  />
                  <BFormInvalidFeedback v-if="passwordError">
                    {{ passwordError }}
                  </BFormInvalidFeedback>
                </BFormGroup>

                <!-- Form Buttons -->
                <BFormGroup>
                  <BButton class="ms-2" variant="outline-dark" @click="handleReset">
                    Reset
                  </BButton>
                  <BButton class="ms-2" :class="{ shake: animated }" type="submit" variant="dark">
                    Login
                  </BButton>
                </BFormGroup>
              </form>

              <!-- Additional Links -->
              <div>
                Don't have an account yet and want to help?
                <BLink :to="'/Register'"> Register now. </BLink>
              </div>
              <div>
                Forgot your password?
                <BLink :to="'/PasswordReset'"> Reset now. </BLink>
              </div>
            </BCardText>
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { ref } from 'vue';
import { useHead } from '@unhead/vue';
import { useForm, useField, defineRule } from 'vee-validate';
import { required, min, max } from '@vee-validate/rules';
import useToast from '@/composables/useToast';
import { useAuth } from '@/composables/useAuth';

// Define validation rules globally
defineRule('required', required);
defineRule('min', min);
defineRule('max', max);

export default {
  name: 'LoginView',
  setup() {
    const { makeToast } = useToast();
    // Phase E.E7: delegate all auth state reads/writes to `useAuth()`.
    const auth = useAuth();
    useHead({
      title: 'Login',
      meta: [
        {
          name: 'description',
          content: 'The Login view allows users and curators to log into their SysNDD account.',
        },
      ],
    });

    // Setup form validation with vee-validate 4
    const { handleSubmit, resetForm: resetVeeForm } = useForm();

    // Define fields with validation
    const {
      value: user_name,
      errorMessage: usernameError,
      meta: usernameMeta,
    } = useField('username', 'required|min:5|max:20');

    const {
      value: password,
      errorMessage: passwordError,
      meta: passwordMeta,
    } = useField('password', 'required|min:5|max:50');

    const loading = ref(true);
    const animated = ref(false);

    return {
      user_name,
      usernameError,
      usernameMeta,
      password,
      passwordError,
      passwordMeta,
      loading,
      animated,
      handleSubmit,
      resetVeeForm,
      makeToast,
      auth,
    };
  },
  mounted() {
    // If the Login view is reached while still authenticated, clear the
    // session before showing the form (matches the pre-refactor behaviour).
    if (this.auth.isAuthenticated.value) {
      this.doUserLogOut();
    }
    this.loading = false;
  },
  methods: {
    onSubmit() {
      this.handleSubmit((_values) => {
        this.loadJWT();
      })();
    },
    async loadJWT() {
      // OWASP: credentials MUST go in the JSON body, never in URL query params
      // (query strings leak into access logs, Traefik logs, and browser history).
      // See api/endpoints/authentication_endpoints.R `@post authenticate`.
      const apiAuthenticateURL = `${import.meta.env.VITE_API_URL}/api/auth/authenticate`;
      try {
        const response_authenticate = await this.axios.post(apiAuthenticateURL, {
          user_name: this.user_name,
          password: this.password,
        });
        // R/Plumber wraps the scalar token in a single-element array, but
        // master also tolerated a bare string body. Validate the shape before
        // calling signinWithJWT — without this guard (Copilot Fix 4), a
        // malformed 200 response would hand `undefined` to signinWithJWT,
        // which would then send "Bearer undefined" to /signin and call
        // `auth.login(undefined, ...)` after it (eventually) succeeded or
        // failed with a confusing 401.
        const raw = response_authenticate.data;
        let token;
        if (typeof raw === 'string') {
          token = raw;
        } else if (Array.isArray(raw) && raw.length > 0 && typeof raw[0] === 'string') {
          token = raw[0];
        } else {
          this.makeToast(
            'Authentication failed: invalid token shape from server',
            'Error',
            'danger'
          );
          return;
        }
        if (!token) {
          this.makeToast(
            'Authentication failed: empty token from server',
            'Error',
            'danger'
          );
          return;
        }
        this.makeToast(
          `You have logged in (status ${response_authenticate.status} - ${response_authenticate.statusText}).`,
          'Success',
          'success'
        );
        this.signinWithJWT(token);
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async signinWithJWT(token) {
      // Two-step login: (1) POST /authenticate returned the JWT above;
      // (2) GET /signin exchanges it for the full user payload. We set the
      // Authorization header manually for this single call because
      // `auth.login()` only fires after we have both pieces — splitting
      // login into "set token" + "set user" would expose an intermediate
      // half-logged-in state other tabs/components could observe.
      const apiAuthenticateURL = `${import.meta.env.VITE_API_URL}/api/auth/signin`;
      try {
        const response_signin = await this.axios.get(apiAuthenticateURL, {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        });
        this.auth.login(token, response_signin.data);
        this.$router.push('/');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    handleReset() {
      this.user_name = '';
      this.password = '';
      this.resetVeeForm();
    },
    doUserLogOut() {
      if (this.auth.isAuthenticated.value) {
        this.auth.logout();
        this.$router.push('/');
      }
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
