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
          <b-card
            header="Register new SysNDD account"
            header-bg-variant="dark"
            header-text-variant="white"
          >
            <b-overlay
              :show="show_overlay"
              rounded="sm"
            >
              <b-card-text>
                <validation-observer
                  ref="observer"
                  v-slot="{ handleSubmit }"
                >
                  <b-form @submit.stop.prevent="handleSubmit(onSubmit)">
                    <validation-provider
                      v-slot="validationContext"
                      name="username"
                      :rules="{ required: true, min: 5, max: 20 }"
                    >
                      <b-form-group
                        description="Enter your prefered user name (min 5 chars)"
                      >
                        <b-form-input
                          v-model="registration_form.user_name"
                          placeholder="Username"
                          :state="getValidationState(validationContext)"
                        />
                      </b-form-group>
                    </validation-provider>

                    <validation-provider
                      v-slot="validationContext"
                      name="email"
                      :rules="{ required: true, email: true }"
                    >
                      <b-form-group
                        description="Enter your institutional mail account"
                      >
                        <b-form-input
                          v-model="registration_form.email"
                          placeholder="mail@your-institution.com"
                          :state="getValidationState(validationContext)"
                        />
                      </b-form-group>
                    </validation-provider>

                    <validation-provider
                      v-slot="validationContext"
                      name="orcid"
                      :rules="{
                        required: true,
                        regex: /^(([0-9]{4})-){3}[0-9]{3}[0-9X]$/,
                      }"
                    >
                      <b-form-group description="Enter your ORCID">
                        <b-form-input
                          v-model="registration_form.orcid"
                          placeholder="NNNN-NNNN-NNNN-NNNX"
                          :state="getValidationState(validationContext)"
                        />
                      </b-form-group>
                    </validation-provider>

                    <validation-provider
                      v-slot="validationContext"
                      name="firstname"
                      :rules="{ required: true, min: 2, max: 50 }"
                    >
                      <b-form-group description="Enter your first name">
                        <b-form-input
                          v-model="registration_form.first_name"
                          placeholder="First name"
                          :state="getValidationState(validationContext)"
                        />
                      </b-form-group>
                    </validation-provider>

                    <validation-provider
                      v-slot="validationContext"
                      name="familyname"
                      :rules="{ required: true, min: 2, max: 50 }"
                    >
                      <b-form-group description="Enter your family name">
                        <b-form-input
                          v-model="registration_form.family_name"
                          placeholder="Family name"
                          :state="getValidationState(validationContext)"
                        />
                      </b-form-group>
                    </validation-provider>

                    <validation-provider
                      v-slot="validationContext"
                      name="sysnddcomment"
                      :rules="{ required: true, min: 10, max: 250 }"
                    >
                      <b-form-group
                        description="Please describe why you want to help with SysNDD"
                      >
                        <b-form-input
                          v-model="registration_form.comment"
                          placeholder="Your interest in SysNDD"
                          :state="getValidationState(validationContext)"
                        />
                      </b-form-group>
                    </validation-provider>

                    <validation-provider
                      v-slot="validationContext"
                      name="termsagreed"
                      :rules="{ required: true, is: 'accepted' }"
                    >
                      <b-form-group>
                        <b-form-checkbox
                          v-model="registration_form.terms_agreed"
                          value="accepted"
                          unchecked-value="not_accepted"
                          :state="getValidationState(validationContext)"
                        >
                          I accept the terms and use
                        </b-form-checkbox>
                      </b-form-group>
                    </validation-provider>

                    <b-form-group>
                      <b-button
                        class="ml-2"
                        variant="outline-dark"
                        @click="resetForm()"
                      >
                        Reset
                      </b-button>
                      <b-button
                        class="ml-2"
                        :class="{ shake: animated }"
                        type="submit"
                        variant="dark"
                        @click="clickHandler()"
                      >
                        Register
                      </b-button>
                    </b-form-group>
                  </b-form>
                </validation-observer>
              </b-card-text>

              <template #overlay>
                <div class="text-center">
                  <b-icon
                    icon="clipboard-check"
                    font-scale="3"
                    animation="cylon"
                  />
                  <p>Request send. Redirecting now...</p>
                </div>
              </template>
            </b-overlay>
          </b-card>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';

export default {
  name: 'Register',
  mixins: [toastMixin],
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Register',
    // all titles will be injected into this template
    titleTemplate:
      '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en',
    },
    meta: [
      {
        vmid: 'description',
        name: 'description',
        content: 'The Register view allows to appy for a new SysNDD account.',
      },
    ],
  },
  data() {
    return {
      registration_form: {
        user_name: '',
        email: '',
        orcid: '',
        first_name: '',
        family_name: '',
        comment: '',
        terms_agreed: 'not_accepted',
      },
      animated: false,
      show_overlay: false,
      loading: true,
    };
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
    async sendRegistration() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/auth/signup?signup_data=`;

      try {
        const submission_json = JSON.stringify(this.registration_form);
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
    onSubmit(event) {
      this.sendRegistration();
    },
    clickHandler() {
      const self = this;
      self.animated = true;
      setTimeout(() => {
        self.animated = false;
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
