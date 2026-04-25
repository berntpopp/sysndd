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
import { authenticate, signin } from '@/api/auth';
import { isApiError } from '@/api/client';

/**
 * Extract a human-readable string from an error thrown by the typed
 * api/auth helpers. v11.1 finish-hardening fix #2: the catch handlers
 * previously passed the raw `AxiosError` object to `makeToast`, which
 * rendered as `[object Object]` (or the bare class name) in the toast
 * body. Prefer, in order:
 *
 *   1. The API's response body string (handler returns `"User or password
 *      wrong."` for a 401).
 *   2. A `.message` field on a JSON error envelope (`{ message: '...' }`).
 *   3. The Error.message (network failures, validation throws).
 *   4. A generic "Authentication failed." fallback.
 *
 * Returns a string in every case so the caller can pass it to `makeToast`
 * without an additional unwrap step.
 */
function describeAuthError(err, fallback = 'Authentication failed.') {
  if (isApiError(err)) {
    const data = err.response && err.response.data;
    if (typeof data === 'string' && data.length > 0) {
      return data;
    }
    if (
      data &&
      typeof data === 'object' &&
      typeof data.message === 'string' &&
      data.message.length > 0
    ) {
      return data.message;
    }
    if (typeof err.message === 'string' && err.message.length > 0) {
      return err.message;
    }
  }
  if (err instanceof Error && typeof err.message === 'string' && err.message.length > 0) {
    return err.message;
  }
  if (typeof err === 'string' && err.length > 0) {
    return err;
  }
  return fallback;
}

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
      // The typed `authenticate()` helper unwraps the Plumber scalar-array
      // envelope before returning the bare token string.
      try {
        const token = await authenticate(this.user_name, this.password);
        if (typeof token !== 'string' || !token) {
          this.makeToast(
            'Authentication failed: invalid token shape from server',
            'Error',
            'danger'
          );
          return;
        }
        this.makeToast(
          'You have logged in.',
          'Success',
          'success'
        );
        this.signinWithJWT(token);
      } catch (e) {
        // v11.1 finish-hardening fix #2: surface the API's literal message
        // (e.g. "User or password wrong." for 401) instead of toasting the
        // raw AxiosError object — which otherwise renders as [object Object].
        this.makeToast(describeAuthError(e), 'Error', 'danger');
      }
    },
    async signinWithJWT(token) {
      // Two-step login: (1) POST /authenticate returned the JWT above;
      // (2) GET /signin exchanges it for the full user payload. We set the
      // Authorization header manually for this single call because
      // `auth.login()` only fires after we have both pieces — splitting
      // login into "set token" + "set user" would expose an intermediate
      // half-logged-in state other tabs/components could observe.
      try {
        const userPayload = await signin({
          headers: {
            Authorization: `Bearer ${token}`, // closeout-exception-E1: bootstrap two-step handshake; useAuth.login() requires both token+user atomically (§3.4)
          },
        });
        this.auth.login(token, userPayload);
        this.$router.push('/');
      } catch (e) {
        // v11.1 finish-hardening fix #2: same anti-pattern as loadJWT — pass
        // a readable string to makeToast so the user sees the API's actual
        // error reason instead of [object Object].
        this.makeToast(describeAuthError(e), 'Error', 'danger');
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
