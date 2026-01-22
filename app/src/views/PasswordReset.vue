<!-- src/views/PasswordReset.vue -->
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
          <BContainer v-if="showChangeContainer">
            <BCard
              header="Reset Password"
              header-bg-variant="dark"
              header-text-variant="white"
            >
              <BCardText>
                <ValidationObserver
                  ref="observer"
                  v-slot="{ handleSubmit }"
                >
                  <BForm @submit.stop.prevent="handleSubmit(doPasswordChange)">
                    <ValidationProvider
                      v-slot="validationContext"
                      name="password"
                      :rules="{ required: true, min: 7, max: 50 }"
                    >
                      <BFormGroup description="Enter your new password">
                        <BFormInput
                          v-model="newPasswordEntry"
                          placeholder="Enter new password"
                          type="password"
                          :state="getValidationState(validationContext)"
                        />
                      </BFormGroup>
                    </ValidationProvider>

                    <ValidationProvider
                      v-slot="validationContext"
                      name="repeatPassword"
                      :rules="{ required: true, min: 7, max: 50 }"
                    >
                      <BFormGroup description="Repeat your new password">
                        <BFormInput
                          v-model="newPasswordRepeat"
                          placeholder="Repeat new password"
                          type="password"
                          :state="getValidationState(validationContext)"
                        />
                      </BFormGroup>
                    </ValidationProvider>

                    <BFormGroup>
                      <BButton
                        class="ms-2"
                        type="submit"
                        variant="dark"
                      >
                        Submit change
                      </BButton>
                    </BFormGroup>
                  </BForm>
                </ValidationObserver>
              </BCardText>
            </BCard>
          </BContainer>

          <BContainer v-if="showRequestContainer">
            <BCard
              header="Reset Password"
              header-bg-variant="dark"
              header-text-variant="white"
            >
              <BCardText>
                <ValidationObserver
                  ref="observer"
                  v-slot="{ handleSubmit }"
                >
                  <BForm @submit.stop.prevent="handleSubmit(requestPasswordReset)">
                    <ValidationProvider
                      v-slot="validationContext"
                      name="email"
                      :rules="{ required: true, email: true }"
                    >
                      <BFormGroup description="Enter your mail account">
                        <BFormInput
                          v-model="emailEntry"
                          placeholder="mail@your-institution.com"
                          :state="getValidationState(validationContext)"
                        />
                      </BFormGroup>
                    </ValidationProvider>

                    <BFormGroup>
                      <BButton
                        class="ms-2"
                        type="submit"
                        variant="dark"
                      >
                        Submit
                      </BButton>
                    </BFormGroup>
                  </BForm>
                </ValidationObserver>
              </BCardText>
            </BCard>
          </BContainer>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { ValidationObserver, ValidationProvider } from 'vee-validate';
import toastMixin from '@/assets/js/mixins/toastMixin';

export default {
  name: 'PasswordReset',
  components: {
    ValidationObserver,
    ValidationProvider,
  },
  mixins: [toastMixin],
  data() {
    return {
      showChangeContainer: false,
      showRequestContainer: true,
      emailEntry: '',
      newPasswordEntry: '',
      newPasswordRepeat: '',
      loading: true,
    };
  },
  mounted() {
    this.checkURLParameter();
  },
  methods: {
    getValidationState(validationContext) {
      if (validationContext.errors[0]) {
        return false;
      }
      if (validationContext.dirty || validationContext.validated) {
        return validationContext.valid;
      }
      return null;
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
      } catch (e) {
        return null;
      }
    },
    async requestPasswordReset() {
      const apiPasswordResetRequest = `${process.env.VUE_APP_API_URL
      }/api/user/password/reset/request?email_request=${
        this.emailEntry}`;

      try {
        const responseResetRequest = await this.axios.get(apiPasswordResetRequest);
        this.makeToast(
          `If the mail exists your request has been sent (status ${responseResetRequest.status} - ${responseResetRequest.statusText}).`,
          'Success',
          'success',
        );
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.resetRequestForm();
    },
    resetRequestForm() {
      this.emailEntry = '';
      setTimeout(() => {
        this.$router.push('/');
      }, 1000);
    },
    async doPasswordChange() {
      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/user/password/reset/change?new_pass_1=${
        this.newPasswordEntry
      }&new_pass_2=${
        this.newPasswordRepeat}`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${this.$route.params.request_jwt}`,
          },
        });
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.resetChangeForm();
    },
    resetChangeForm() {
      this.newPasswordEntry = '';
      this.newPasswordRepeat = '';
      setTimeout(() => {
        this.$router.push('/');
      }, 1000);
    },
  },
};
</script>
