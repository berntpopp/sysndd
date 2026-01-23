<template>
  <div class="container-fluid">
    <BSpinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />

    <BContainer v-else>
      <BRow class="justify-content-md-center py-4">
        <BCol md="6">
          <BCard
            header="Register new SysNDD account"
            header-bg-variant="dark"
            header-text-variant="white"
          >
            <BOverlay
              :show="show_overlay"
              rounded="sm"
            >
              <BCardText>
                <BForm @submit.prevent="onSubmit">
                  <BFormGroup
                    description="Enter your preferred user name (min 5 chars)"
                  >
                    <BFormInput
                      v-model="user_name"
                      placeholder="Username"
                      :state="usernameMeta.touched ? (usernameError ? false : true) : null"
                    />
                    <BFormInvalidFeedback v-if="usernameError">
                      {{ usernameError }}
                    </BFormInvalidFeedback>
                  </BFormGroup>

                  <BFormGroup
                    description="Enter your institutional mail account"
                  >
                    <BFormInput
                      v-model="email"
                      placeholder="mail@your-institution.com"
                      :state="emailMeta.touched ? (emailError ? false : true) : null"
                    />
                    <BFormInvalidFeedback v-if="emailError">
                      {{ emailError }}
                    </BFormInvalidFeedback>
                  </BFormGroup>

                  <BFormGroup description="Enter your ORCID">
                    <BFormInput
                      v-model="orcid"
                      placeholder="NNNN-NNNN-NNNN-NNNX"
                      :state="orcidMeta.touched ? (orcidError ? false : true) : null"
                    />
                    <BFormInvalidFeedback v-if="orcidError">
                      {{ orcidError }}
                    </BFormInvalidFeedback>
                  </BFormGroup>

                  <BFormGroup description="Enter your first name">
                    <BFormInput
                      v-model="first_name"
                      placeholder="First name"
                      :state="firstnameMeta.touched ? (firstnameError ? false : true) : null"
                    />
                    <BFormInvalidFeedback v-if="firstnameError">
                      {{ firstnameError }}
                    </BFormInvalidFeedback>
                  </BFormGroup>

                  <BFormGroup description="Enter your family name">
                    <BFormInput
                      v-model="family_name"
                      placeholder="Family name"
                      :state="familynameMeta.touched ? (familynameError ? false : true) : null"
                    />
                    <BFormInvalidFeedback v-if="familynameError">
                      {{ familynameError }}
                    </BFormInvalidFeedback>
                  </BFormGroup>

                  <BFormGroup
                    description="Please describe why you want to help with SysNDD"
                  >
                    <BFormInput
                      v-model="comment"
                      placeholder="Your interest in SysNDD"
                      :state="commentMeta.touched ? (commentError ? false : true) : null"
                    />
                    <BFormInvalidFeedback v-if="commentError">
                      {{ commentError }}
                    </BFormInvalidFeedback>
                  </BFormGroup>

                  <BFormGroup>
                    <BFormCheckbox
                      v-model="terms_agreed"
                      value="accepted"
                      unchecked-value="not_accepted"
                      :state="termsMeta.touched ? (termsError ? false : true) : null"
                    >
                      I accept the terms and use
                    </BFormCheckbox>
                    <BFormInvalidFeedback v-if="termsError" class="d-block">
                      {{ termsError }}
                    </BFormInvalidFeedback>
                  </BFormGroup>

                  <BFormGroup>
                    <BButton
                      class="ms-2"
                      variant="outline-dark"
                      @click="handleReset()"
                    >
                      Reset
                    </BButton>
                    <BButton
                      class="ms-2"
                      :class="{ shake: animated }"
                      type="submit"
                      variant="dark"
                      @click="clickHandler()"
                    >
                      Register
                    </BButton>
                  </BFormGroup>
                </BForm>
              </BCardText>

              <template #overlay>
                <div class="text-center">
                  <BIcon
                    icon="clipboard-check"
                    font-scale="3"
                    animation="cylon"
                  />
                  <p>Request send. Redirecting now...</p>
                </div>
              </template>
            </BOverlay>
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
import { required, min, max, email, regex } from '@vee-validate/rules';
import toastMixin from '@/assets/js/mixins/toastMixin';

// Define validation rules
defineRule('required', required);
defineRule('min', min);
defineRule('max', max);
defineRule('email', email);
defineRule('regex', regex);
defineRule('is', (value, [target]) => {
  return value === target || 'You must accept the terms';
});

export default {
  name: 'Register',
  mixins: [toastMixin],
  setup() {
    useHead({
      title: 'Register',
      meta: [
        {
          name: 'description',
          content: 'The Register view allows to apply for a new SysNDD account.',
        },
      ],
    });

    const { handleSubmit, resetForm: resetVeeForm } = useForm();

    // Define all fields with validation
    const {
      value: user_name,
      errorMessage: usernameError,
      meta: usernameMeta,
    } = useField('username', 'required|min:5|max:20');

    const {
      value: email,
      errorMessage: emailError,
      meta: emailMeta,
    } = useField('email', 'required|email');

    const {
      value: orcid,
      errorMessage: orcidError,
      meta: orcidMeta,
    } = useField('orcid', (value) => {
      if (!value) return 'ORCID is required';
      const orcidRegex = /^(([0-9]{4})-){3}[0-9]{3}[0-9X]$/;
      if (!orcidRegex.test(value)) return 'Invalid ORCID format (NNNN-NNNN-NNNN-NNNX)';
      return true;
    });

    const {
      value: first_name,
      errorMessage: firstnameError,
      meta: firstnameMeta,
    } = useField('firstname', 'required|min:2|max:50');

    const {
      value: family_name,
      errorMessage: familynameError,
      meta: familynameMeta,
    } = useField('familyname', 'required|min:2|max:50');

    const {
      value: comment,
      errorMessage: commentError,
      meta: commentMeta,
    } = useField('comment', 'required|min:10|max:250');

    const {
      value: terms_agreed,
      errorMessage: termsError,
      meta: termsMeta,
    } = useField('terms', (value) => {
      if (value !== 'accepted') return 'You must accept the terms';
      return true;
    });

    // Initialize terms_agreed
    terms_agreed.value = 'not_accepted';

    const animated = ref(false);
    const show_overlay = ref(false);
    const loading = ref(true);

    return {
      user_name,
      usernameError,
      usernameMeta,
      email,
      emailError,
      emailMeta,
      orcid,
      orcidError,
      orcidMeta,
      first_name,
      firstnameError,
      firstnameMeta,
      family_name,
      familynameError,
      familynameMeta,
      comment,
      commentError,
      commentMeta,
      terms_agreed,
      termsError,
      termsMeta,
      animated,
      show_overlay,
      loading,
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
      this.handleSubmit(() => {
        this.sendRegistration();
      })();
    },
    async sendRegistration() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/auth/signup?signup_data=`;

      const registration_form = {
        user_name: this.user_name,
        email: this.email,
        orcid: this.orcid,
        first_name: this.first_name,
        family_name: this.family_name,
        comment: this.comment,
        terms_agreed: this.terms_agreed,
      };

      try {
        const submission_json = JSON.stringify(registration_form);
        const response = await this.axios.get(apiUrl + submission_json, {});
        this.makeToast(
          `${'Your registration request has been send '
            + '(status '}${
            response.status
          } (${
            response.statusText
          }).`,
          'Success',
          'success',
        );
        this.successfulRegistration();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    successfulRegistration() {
      this.show_overlay = true;
      setTimeout(() => {
        this.$router.push('/');
      }, 2000);
    },
    handleReset() {
      this.user_name = '';
      this.email = '';
      this.orcid = '';
      this.first_name = '';
      this.family_name = '';
      this.comment = '';
      this.terms_agreed = 'not_accepted';
      this.resetVeeForm();
    },
    clickHandler() {
      this.animated = true;
      setTimeout(() => {
        this.animated = false;
      }, 1000);
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
  color: #42b983;
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
