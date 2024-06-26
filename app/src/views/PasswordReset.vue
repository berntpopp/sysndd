<template>
  <div class="container-fluid">
    <b-spinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />

    <b-container v-else>
      <b-row class="justify-content-md-center py-4">
        <b-col md="6">
          <b-container v-if="show_change_container">
            <b-card
              header="Reset Password"
              header-bg-variant="dark"
              header-text-variant="white"
            >
              <b-card-text>
                <validation-observer
                  ref="observer"
                  v-slot="{ handleSubmit }"
                >
                  <b-form @submit.stop.prevent="handleSubmit(doPasswordChange)">
                    <validation-provider
                      v-slot="validationContext"
                      name="password"
                      :rules="{ required: true, min: 7, max: 50 }"
                    >
                      <b-form-group description="Enter your new password">
                        <b-form-input
                          v-model="new_password_entry"
                          placeholder="Enter new password"
                          type="password"
                          :state="getValidationState(validationContext)"
                        />
                      </b-form-group>
                    </validation-provider>

                    <validation-provider
                      v-slot="validationContext"
                      name="password"
                      :rules="{ required: true, min: 7, max: 50 }"
                    >
                      <b-form-group description="Repeat your new password">
                        <b-form-input
                          v-model="new_password_repeat"
                          placeholder="Repeat new password"
                          type="password"
                          :state="getValidationState(validationContext)"
                        />
                      </b-form-group>
                    </validation-provider>

                    <b-form-group>
                      <b-button
                        class="ml-2"
                        type="submit"
                        variant="dark"
                      >
                        Submit change
                      </b-button>
                    </b-form-group>
                  </b-form>
                </validation-observer>
              </b-card-text>
            </b-card>
          </b-container>

          <b-container v-if="show_request_container">
            <b-card
              header="Reset Password"
              header-bg-variant="dark"
              header-text-variant="white"
            >
              <b-card-text>
                <validation-observer
                  ref="observer"
                  v-slot="{ handleSubmit }"
                >
                  <b-form
                    @submit.stop.prevent="handleSubmit(requestPasswordReset)"
                  >
                    <validation-provider
                      v-slot="validationContext"
                      name="email"
                      :rules="{ required: true, email: true }"
                    >
                      <b-form-group description="Enter your mail account">
                        <b-form-input
                          v-model="email_entry"
                          placeholder="mail@your-institution.com"
                          :state="getValidationState(validationContext)"
                        />
                      </b-form-group>
                    </validation-provider>

                    <b-form-group>
                      <b-button
                        class="ml-2"
                        type="submit"
                        variant="dark"
                      >
                        Submit
                      </b-button>
                    </b-form-group>
                  </b-form>
                </validation-observer>
              </b-card-text>
            </b-card>
          </b-container>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';

export default {
  name: 'PasswordReset',
  mixins: [toastMixin],
  data() {
    return {
      show_change_container: false,
      show_request_container: true,
      email_entry: '',
      new_password_entry: '',
      new_password_repeat: '',
      loading: true,
    };
  },
  mounted() {
    this.checkURLParameter();
  },
  methods: {
    getValidationState({ dirty, validated, valid = null }) {
      return dirty || validated ? valid : null;
    },
    async checkURLParameter() {
      this.loading = true;

      const decode_jwt = this.parseJwt(this.$route.params.request_jwt);
      const timestamp = Math.floor(new Date().getTime() / 1000);

      if (decode_jwt === null) {
        this.show_change_container = false;
        this.show_request_container = true;
      } else if (decode_jwt.exp < timestamp) {
        setTimeout(() => {
          this.$router.push('/');
        }, 1000);
      } else {
        this.show_change_container = true;
        this.show_request_container = false;
      }
      this.loading = false;
    },
    parseJwt(token) {
      // based on https://stackoverflow.com/questions/51292406/check-if-token-expired-using-this-jwt-library
      try {
        return JSON.parse(atob(token.split('.')[1]));
      } catch (e) {
        return null;
      }
    },
    async requestPasswordReset() {
      const apiPasswordResetRequest = `${process.env.VUE_APP_API_URL
      }/api/user/password/reset/request?email_request=${
        this.email_entry}`;

      try {
        const response_reset_request = await this.axios.get(
          apiPasswordResetRequest,
          {},
        );
        this.makeToast(
          `${'If the mail exists your request has been send '
            + '(status '}${
            response_reset_request.status
          } (${
            response_reset_request.statusText
          }).`,
          'Success',
          'success',
        );
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.resetRequestForm();
    },
    resetRequestForm() {
      this.email_entry = '';
      setTimeout(() => {
        this.$router.push('/');
      }, 1000);
    },
    async doPasswordChange() {
      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/user/password/reset/change?new_pass_1=${
        this.new_password_entry
      }&new_pass_2=${
        this.new_password_repeat}`;
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
      this.new_password_entry = '';
      this.new_password_repeat = '';
      setTimeout(() => {
        this.$router.push('/');
      }, 1000);
    },
  },
};
</script>
