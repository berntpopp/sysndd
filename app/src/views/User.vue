<template>
  <div class="container-fluid centered">
    <BContainer>
      <BRow class="justify-content-md-center py-4">
        <BCol md="6">
          <BCard
            no-body
            class="overflow-hidden"
            style="max-width: 540px"
          >
            <BRow align-v="center">
              <BCol>
                <BCardBody>
                  <BCardTitle>
                    <BAvatar
                      :variant="user_style[user.user_role[0]]"
                      :badge-variant="user_style[user.user_role[0]]"
                      class="justify-content-md-center"
                      size="5rem"
                      badge-offset="-12px"
                      badge-bottom
                    >
                      <i :class="'bi bi-' + user_icon[user.user_role[0]] + ' me-1'" />
                      {{ user.abbreviation[0] }}
                      <template #badge>
                        {{ user.user_role[0] }}
                      </template>
                    </BAvatar>
                  </BCardTitle>

                  <BListGroup flush>
                    <BListGroupItem>
                      Username:
                      <BBadge
                        :variant="user_style[user.user_role[0]]"
                      >
                        {{ user.user_name[0] }}
                      </BBadge>
                    </BListGroupItem>
                    <BListGroupItem>
                      Contributions: Reviews:
                      <BBadge variant="info">
                        {{ user.active_reviews }}
                      </BBadge>, Status:
                      <BBadge variant="info">
                        {{ user.active_status }}
                      </BBadge>
                    </BListGroupItem>
                    <BListGroupItem>
                      Account created:
                      {{ user.user_created[0] }}
                    </BListGroupItem>
                    <BListGroupItem>
                      E-Mail: {{ user.email[0] }}
                    </BListGroupItem>
                    <BListGroupItem>
                      ORCID:
                      <BLink
                        :href="'https://orcid.org/' + user.orcid[0]"
                        target="_blank"
                      >
                        {{ user.orcid[0] }}
                      </BLink>
                    </BListGroupItem>
                    <BListGroupItem>
                      Token expires:
                      <BBadge
                        class="ms-1"
                        variant="info"
                      >
                        {{ Math.floor(time_to_logout) }} m
                        {{
                          (
                            (time_to_logout -
                              Math.floor(time_to_logout)) *
                            60
                          ).toFixed(0)
                        }}
                        s
                      </BBadge>
                      <BBadge
                        class="ms-1"
                        href="#"
                        variant="success"
                        pill
                        @click="refreshWithJWT"
                      >
                        <i class="bi bi-arrow-repeat" />
                      </BBadge>
                    </BListGroupItem>

                    <BListGroupItem>
                      <BButton
                        class="m-1"
                        size="sm"
                        :class="pass_change_visible ? null : 'collapsed'"
                        :aria-expanded="pass_change_visible ? 'true' : 'false'"
                        aria-controls="collapse-4"
                        @click="pass_change_visible = !pass_change_visible"
                      >
                        Change password
                      </BButton>
                      <BCollapse
                        id="collapse-pass-change"
                        v-model="pass_change_visible"
                      >
                        <validation-observer
                          ref="observer"
                          v-slot="{ handleSubmit }"
                        >
                          <BForm
                            @submit.stop.prevent="handleSubmit(changePassword)"
                          >
                            <validation-provider
                              v-slot="validationContext"
                              name="password"
                              :rules="{ required: true, min: 5, max: 50 }"
                            >
                              <BFormGroup
                                description="Enter your current password"
                              >
                                <BFormInput
                                  v-model="current_password"
                                  placeholder="Current password"
                                  type="password"
                                  :state="getValidationState(validationContext)"
                                />
                              </BFormGroup>
                            </validation-provider>

                            <validation-provider
                              v-slot="validationContext"
                              vid="newPassword"
                              :rules="{ required: true,
                                        min: 8,
                                        max: 50,
                                        regex: /(?=.*[!@#$%^&*])(?=.*[A-Z])(?=.*[a-z])(?=.*[\d])/,
                              }"
                            >
                              <BFormGroup
                                v-b-tooltip.hover.right
                                description="Enter your new password"
                                title="Rules: >7 characters, at least one upper character, one lower character, one decimal number and one special character (!@#$%^&*)."
                              >
                                <BFormInput
                                  v-model="new_password_entry"
                                  placeholder="Enter new password"
                                  type="password"
                                  :state="getValidationState(validationContext)"
                                />
                              </BFormGroup>
                            </validation-provider>

                            <validation-provider
                              v-slot="validationContext"
                              vid="confirmPassword"
                              :rules="{ required: true,
                                        min: 8,
                                        max: 50,
                                        regex: /(?=.*[!@#$%^&*])(?=.*[A-Z])(?=.*[a-z])(?=.*[\d])/,
                                        confirmed: 'newPassword',
                              }"
                            >
                              <BFormGroup
                                v-b-tooltip.hover.right
                                description="Repeat your new password"
                                title="Rules: must match first input."
                              >
                                <BFormInput
                                  v-model="new_password_repeat"
                                  placeholder="Repeat new password"
                                  type="password"
                                  :state="getValidationState(validationContext)"
                                />
                              </BFormGroup>
                            </validation-provider>

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
                        </validation-observer>
                      </BCollapse>
                    </BListGroupItem>
                  </BListGroup>
                </BCardBody>
              </BCol>
            </BRow>
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useToast, useColorAndSymbols } from '@/composables';

export default {
  name: 'User',
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();

    return {
      makeToast,
      ...colorAndSymbols,
    };
  },
  data() {
    return {
      user: {
        user_id: [],
        user_name: [],
        email: [],
        user_role: [],
        user_created: [],
        abbreviation: [],
        orcid: [],
        exp: [],
        active_reviews: 0,
        active_status: 0,
      },
      time_to_logout: 0,
      pass_change_visible: false,
      current_password: '',
      new_password_entry: '',
      new_password_repeat: '',
    };
  },
  mounted() {
    if (localStorage.user) {
      this.user = JSON.parse(localStorage.user);

      this.interval = setInterval(() => {
        this.updateDiffs();
      }, 1000);

      this.updateDiffs();
      this.getUserContributions();
    }
  },
  beforeUnmount() {
    clearInterval(this.interval);
  },
  methods: {
    getValidationState({ dirty, validated, valid = null }) {
      return dirty || validated ? valid : null;
    },
    // TODO: change function name to something more meaningful and non redundant
    updateDiffs() {
      if (localStorage.token) {
        const expires = JSON.parse(localStorage.user).exp;
        const timestamp = Math.floor(new Date().getTime() / 1000);
        this.time_to_logout = ((expires - timestamp) / 60).toFixed(2);
      }
    },
    async getUserContributions() {
      const apiContributionsURL = `${import.meta.env.VITE_API_URL
      }/api/user/${
        this.user.user_id[0]
      }/contributions`;

      try {
        const response_contributions = await this.axios.get(apiContributionsURL, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        let rest;
        [this.user.active_reviews, ...rest] = response_contributions.data.active_reviews;
        [this.user.active_status, ...rest] = response_contributions.data.active_status;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async refreshWithJWT() {
      const apiAuthenticateURL = `${import.meta.env.VITE_API_URL}/api/auth/refresh`;

      try {
        const response_refresh = await this.axios.get(apiAuthenticateURL, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });

        localStorage.setItem('token', response_refresh.data[0]);
        this.signinWithJWT();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async signinWithJWT() {
      const apiAuthenticateURL = `${import.meta.env.VITE_API_URL}/api/auth/signin`;

      try {
        const response_signin = await this.axios.get(apiAuthenticateURL, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });

        localStorage.setItem('user', JSON.stringify(response_signin.data));
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async changePassword() {
      const apiChangePasswordURL = `${import.meta.env.VITE_API_URL
      }/api/user/password/update?user_id_pass_change=${
        this.user.user_id[0]
      }&old_pass=${
        this.current_password
      }&new_pass_1=${
        this.new_password_entry
      }&new_pass_2=${
        this.new_password_repeat}`;
      try {
        const response_password_change = await this.axios.put(
          apiChangePasswordURL,
          {},
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );
        this.makeToast(
          `${response_password_change.data.message
          } (status ${
            response_password_change.status
          })`,
          'Success',
          'success',
        );
        this.pass_change_visible = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.pass_change_visible = false;
      }
      this.resetPasswordForm();
    },
    resetPasswordForm() {
      this.current_password = '';
      this.new_password_entry = '';
      this.new_password_repeat = '';
    },
  },
};
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}
.centered {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: calc(100vh - 68px - 50px);
}
</style>
