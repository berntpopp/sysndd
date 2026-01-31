<!-- src/views/PasswordResetView.vue -->
<template>
  <div class="container-fluid">
    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />

    <BContainer v-else>
      <BRow class="justify-content-md-center py-4">
        <BCol md="6">
          <BContainer v-if="showChangeContainer">
            <BCard header="Reset Password" header-bg-variant="dark" header-text-variant="white">
              <BCardText>
                <BForm @submit.prevent="onPasswordChange">
                  <BFormGroup description="Enter your new password">
                    <BFormInput
                      v-model="newPasswordEntry"
                      placeholder="Enter new password"
                      type="password"
                      :state="passwordMeta.touched ? (passwordError ? false : true) : null"
                    />
                    <BFormInvalidFeedback v-if="passwordError">
                      {{ passwordError }}
                    </BFormInvalidFeedback>
                  </BFormGroup>

                  <BFormGroup description="Repeat your new password">
                    <BFormInput
                      v-model="newPasswordRepeat"
                      placeholder="Repeat new password"
                      type="password"
                      :state="
                        repeatPasswordMeta.touched ? (repeatPasswordError ? false : true) : null
                      "
                    />
                    <BFormInvalidFeedback v-if="repeatPasswordError">
                      {{ repeatPasswordError }}
                    </BFormInvalidFeedback>
                  </BFormGroup>

                  <BFormGroup>
                    <BButton class="ms-2" type="submit" variant="dark"> Submit change </BButton>
                  </BFormGroup>
                </BForm>
              </BCardText>
            </BCard>
          </BContainer>

          <BContainer v-if="showRequestContainer">
            <BCard header="Reset Password" header-bg-variant="dark" header-text-variant="white">
              <BCardText>
                <BForm @submit.prevent="onPasswordRequest">
                  <BFormGroup description="Enter your mail account">
                    <BFormInput
                      v-model="emailEntry"
                      placeholder="mail@your-institution.com"
                      :state="emailMeta.touched ? (emailError ? false : true) : null"
                    />
                    <BFormInvalidFeedback v-if="emailError">
                      {{ emailError }}
                    </BFormInvalidFeedback>
                  </BFormGroup>

                  <BFormGroup>
                    <BButton class="ms-2" type="submit" variant="dark"> Submit </BButton>
                  </BFormGroup>
                </BForm>
              </BCardText>
            </BCard>
          </BContainer>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { ref } from 'vue';
import { useHead } from '@unhead/vue';
import { useForm, useField, defineRule } from 'vee-validate';
import { required, min, max, email } from '@vee-validate/rules';
import useToast from '@/composables/useToast';

// Define validation rules
defineRule('required', required);
defineRule('min', min);
defineRule('max', max);
defineRule('email', email);

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
    } = useField('password', 'required|min:7|max:50');

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
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/password/reset/request`;

      try {
        // POST with JSON body per OWASP guidelines (email should not be in URL)
        const responseResetRequest = await this.axios.post(apiUrl, {
          email: this.emailEntry,
        });
        this.makeToast(
          `If the mail exists your request has been sent (status ${responseResetRequest.status} - ${responseResetRequest.statusText}).`,
          'Success',
          'success'
        );
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
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/password/reset/change`;
      try {
        // POST with JSON body per OWASP guidelines (passwords MUST NOT be in URLs)
        await this.axios.post(
          apiUrl,
          {
            password: this.newPasswordEntry,
            password_confirm: this.newPasswordRepeat,
          },
          {
            headers: {
              Authorization: `Bearer ${this.$route.params.request_jwt}`,
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
