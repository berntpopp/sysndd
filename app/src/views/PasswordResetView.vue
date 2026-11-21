<!-- src/views/PasswordResetView.vue -->
<template>
  <div class="login-page">
    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />

    <div v-else class="login-shell login-shell--single">
      <section class="login-panel" aria-labelledby="reset-title">
        <header class="login-panel__header">
          <h1 id="reset-title" class="login-title">Reset password</h1>
          <p class="login-description">
            {{
              showChangeContainer
                ? 'Choose a new password for your SysNDD account.'
                : 'Enter the email address of your SysNDD account and we will send you a reset link.'
            }}
          </p>
        </header>

        <form v-if="showChangeContainer" class="login-form" @submit.prevent="onPasswordChange">
          <BFormGroup
            label="New password"
            label-for="reset-new-password"
            description="At least 8 characters with an uppercase letter, a lowercase letter, a number and one of !@#$%^&amp;*"
          >
            <BFormInput
              id="reset-new-password"
              v-model="newPasswordEntry"
              autocomplete="new-password"
              type="password"
              :state="passwordMeta.touched && passwordError ? false : null"
            />
            <BFormInvalidFeedback v-if="passwordError">
              {{ passwordError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <BFormGroup label="Repeat new password" label-for="reset-repeat-password">
            <BFormInput
              id="reset-repeat-password"
              v-model="newPasswordRepeat"
              autocomplete="new-password"
              type="password"
              :state="repeatPasswordMeta.touched && repeatPasswordError ? false : null"
            />
            <BFormInvalidFeedback v-if="repeatPasswordError">
              {{ repeatPasswordError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <div class="login-actions">
            <BButton type="submit" variant="primary">Change password</BButton>
          </div>
        </form>

        <form
          v-if="showRequestContainer"
          class="login-form"
          novalidate
          @submit.prevent="onPasswordRequest"
        >
          <BFormGroup label="Email address" label-for="reset-email">
            <BFormInput
              id="reset-email"
              v-model="emailEntry"
              type="email"
              autocomplete="email"
              placeholder="name@your-institution.org"
              :state="emailMeta.touched && emailError ? false : null"
            />
            <BFormInvalidFeedback v-if="emailError">
              {{ emailError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <div class="login-actions">
            <BButton type="submit" variant="primary">Send reset link</BButton>
          </div>
        </form>

        <div class="login-links">
          <BLink :to="'/Login'">Back to sign in</BLink>
        </div>
      </section>
    </div>
  </div>
</template>

<script>
import { ref } from 'vue';
import { useHead } from '@unhead/vue';
import { useForm, useField, defineRule } from 'vee-validate';
import { required, min, max, email } from '@vee-validate/rules';
import useToast from '@/composables/useToast';
import { requestPasswordReset, resetPasswordWithToken } from '@/api/user';
import { passwordComplexity } from '@/utils/passwordRules';

// Define validation rules
defineRule('required', required);
defineRule('min', min);
defineRule('max', max);
defineRule('email', email);
defineRule('password_complexity', passwordComplexity);

export default {
  name: 'PasswordResetView',
  setup() {
    const { makeToast } = useToast();
    useHead({
      title: 'Password Reset',
      meta: [
        {
          name: 'description',
          content: 'Reset your SysNDD account password.',
        },
      ],
    });

    // Setup form validation for change password form
    const { handleSubmit: handleChangeSubmit, resetForm: resetChangeVeeForm } = useForm();

    // Setup form validation for request password reset form
    const { handleSubmit: handleRequestSubmit, resetForm: resetRequestVeeForm } = useForm();

    // Define fields for password change
    const {
      value: newPasswordEntry,
      errorMessage: passwordError,
      meta: passwordMeta,
    } = useField('password', 'required|min:8|max:50|password_complexity');

    const {
      value: newPasswordRepeat,
      errorMessage: repeatPasswordError,
      meta: repeatPasswordMeta,
    } = useField('repeatPassword', 'required|min:7|max:50');

    // Define fields for email request
    const {
      value: emailEntry,
      errorMessage: emailError,
      meta: emailMeta,
    } = useField('email', 'required|email');

    const showChangeContainer = ref(false);
    const showRequestContainer = ref(true);
    const loading = ref(true);

    return {
      newPasswordEntry,
      passwordError,
      passwordMeta,
      newPasswordRepeat,
      repeatPasswordError,
      repeatPasswordMeta,
      emailEntry,
      emailError,
      emailMeta,
      showChangeContainer,
      showRequestContainer,
      loading,
      handleChangeSubmit,
      handleRequestSubmit,
      resetChangeVeeForm,
      resetRequestVeeForm,
      makeToast,
    };
  },
  mounted() {
    this.checkURLParameter();
  },
  methods: {
    onPasswordChange() {
      this.handleChangeSubmit(() => {
        this.doPasswordChange();
      })();
    },
    onPasswordRequest() {
      // Validate email format before submitting
      if (!this.emailEntry || !this.emailEntry.includes('@')) {
        this.makeToast('Please enter a valid email address', 'Error', 'danger');
        return;
      }
      this.requestPasswordReset();
    },
    async checkURLParameter() {
      this.loading = true;

      const decodeJwt = this.parseJwt(this.$route.params.request_jwt);
      const timestamp = Math.floor(new Date().getTime() / 1000);

      if (decodeJwt === null) {
        this.showChangeContainer = false;
        this.showRequestContainer = true;
      } else if (decodeJwt.exp < timestamp) {
        setTimeout(() => {
          this.$router.push('/');
        }, 1000);
      } else {
        this.showChangeContainer = true;
        this.showRequestContainer = false;
      }
      this.loading = false;
    },
    parseJwt(token) {
      try {
        return JSON.parse(atob(token.split('.')[1]));
      } catch (_e) {
        return null;
      }
    },
    async requestPasswordReset() {
      try {
        // POST with JSON body per OWASP guidelines (email should not be in URL)
        await requestPasswordReset({
          email: this.emailEntry,
        });
        this.makeToast('If the mail exists your request has been sent.', 'Success', 'success');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.resetRequestForm();
    },
    resetRequestForm() {
      this.emailEntry = '';
      this.resetRequestVeeForm();
      setTimeout(() => {
        this.$router.push('/');
      }, 1000);
    },
    async doPasswordChange() {
      try {
        // POST with JSON body per OWASP guidelines (passwords MUST NOT be in URLs)
        await resetPasswordWithToken(
          {
            password: this.newPasswordEntry,
            password_confirm: this.newPasswordRepeat,
          },
          {
            headers: {
              Authorization: `Bearer ${this.$route.params.request_jwt}`, // closeout-exception-E2: route-param one-shot JWT from email link; not a session token (§3.4)
            },
          }
        );
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.resetChangeForm();
    },
    resetChangeForm() {
      this.newPasswordEntry = '';
      this.newPasswordRepeat = '';
      this.resetChangeVeeForm();
      setTimeout(() => {
        this.$router.push('/');
      }, 1000);
    },
  },
};
</script>
