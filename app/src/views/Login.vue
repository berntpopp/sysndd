<!-- src/views/Login.vue -->
<template>
  <div class="container-fluid">
    <!-- Loading Spinner -->
    <BSpinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />

    <!-- Login Form -->
    <BContainer v-else>
      <BRow class="justify-content-md-center py-4">
        <BCol md="6">
          <BCard
            header="Sign in"
            header-bg-variant="dark"
            header-text-variant="white"
          >
            <BCardText>
              <BForm @submit.prevent="onSubmit">
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
                  <BButton
                    class="ms-2"
                    variant="outline-dark"
                    @click="handleReset"
                  >
                    Reset
                  </BButton>
                  <BButton
                    class="ms-2"
                    :class="{ shake: animated }"
                    type="submit"
                    variant="dark"
                  >
                    Login
                  </BButton>
                </BFormGroup>
              </BForm>

              <!-- Additional Links -->
              <div>
                Don't have an account yet and want to help?
                <BLink :href="'/Register'">
                  Register now.
                </BLink>
              </div>
              <div>
                Forgot your password?
                <BLink :href="'/PasswordReset'">
                  Reset now.
                </BLink>
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
import toastMixin from '@/assets/js/mixins/toastMixin';

// Define validation rules globally
defineRule('required', required);
defineRule('min', min);
defineRule('max', max);

export default {
  name: 'Login',
  mixins: [toastMixin],
  setup() {
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
    };
  },
  mounted() {
    if (localStorage.user) {
      this.doUserLogOut();
    }
    this.loading = false;
  },
  methods: {
    onSubmit() {
      this.handleSubmit((values) => {
        this.loadJWT();
      })();
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
    handleReset() {
      this.user_name = '';
      this.password = '';
      this.resetVeeForm();
    },
    doUserLogOut() {
      if (localStorage.user || localStorage.token) {
        localStorage.removeItem('user');
        localStorage.removeItem('token');
        this.user = null;
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
