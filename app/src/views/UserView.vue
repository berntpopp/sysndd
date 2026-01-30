<!-- views/UserView.vue -->
<!--
  User Profile Page - Modern Design
  Following UI/UX best practices:
  - Identity zone with avatar top-left (89% of apps pattern)
  - Stats cards for contributions
  - Organized sections with icons
  - Progressive disclosure for security settings
  - Clean minimalist layout with clear hierarchy
-->
<template>
  <div class="container-fluid">
    <BContainer class="py-4">
      <BRow class="justify-content-center">
        <BCol lg="8" xl="6">
          <!-- Profile Header Card -->
          <BCard class="border-0 shadow-sm mb-4 overflow-hidden">
            <!-- Header Background -->
            <div class="profile-header-bg" :class="`bg-${roleVariant}-subtle`" />

            <BCardBody class="position-relative pt-0">
              <!-- Avatar & Identity Zone -->
              <div
                class="d-flex flex-column flex-sm-row align-items-center align-items-sm-end gap-3 profile-identity"
              >
                <div class="avatar-wrapper">
                  <div
                    class="avatar-circle d-flex align-items-center justify-content-center"
                    :class="`bg-${roleVariant} text-white`"
                  >
                    <span class="avatar-initials">{{ user.abbreviation[0] }}</span>
                  </div>
                  <span
                    class="avatar-badge d-flex align-items-center justify-content-center"
                    :class="`bg-${roleVariant}`"
                  >
                    <i :class="`bi bi-${roleIcon}`" />
                  </span>
                </div>

                <div class="text-center text-sm-start flex-grow-1 pb-2">
                  <h4 class="mb-1 fw-bold">
                    {{ user.user_name[0] }}
                  </h4>
                  <div
                    class="d-flex flex-wrap align-items-center justify-content-center justify-content-sm-start gap-2"
                  >
                    <BBadge :variant="roleVariant" class="d-inline-flex align-items-center gap-1">
                      <i :class="`bi bi-${roleIcon}`" />
                      {{ user.user_role[0] }}
                    </BBadge>
                    <span class="text-muted small">
                      <i class="bi bi-calendar3 me-1" />
                      Member since {{ formatDate(user.user_created[0]) }}
                    </span>
                  </div>
                </div>

                <!-- Session Status -->
                <div class="session-badge d-none d-md-flex align-items-center gap-2">
                  <span
                    class="d-flex align-items-center gap-1 px-2 py-1 rounded-pill"
                    :class="sessionStatusClass"
                  >
                    <i class="bi bi-circle-fill" style="font-size: 0.5rem" />
                    <span class="small">{{ sessionStatusText }}</span>
                  </span>
                </div>
              </div>
            </BCardBody>
          </BCard>

          <!-- Stats Cards Row -->
          <BRow class="mb-4 g-3">
            <BCol cols="6">
              <BCard class="border-0 shadow-sm h-100 stat-card" body-class="text-center py-4">
                <div class="stat-icon mb-2">
                  <span
                    class="d-inline-flex align-items-center justify-content-center rounded-circle bg-primary-subtle text-primary"
                  >
                    <i class="bi bi-journal-check" />
                  </span>
                </div>
                <h3 class="mb-1 fw-bold text-primary">
                  {{ user.active_reviews }}
                </h3>
                <p class="mb-0 text-muted small">Active Reviews</p>
              </BCard>
            </BCol>
            <BCol cols="6">
              <BCard class="border-0 shadow-sm h-100 stat-card" body-class="text-center py-4">
                <div class="stat-icon mb-2">
                  <span
                    class="d-inline-flex align-items-center justify-content-center rounded-circle bg-success-subtle text-success"
                  >
                    <i class="bi bi-check2-square" />
                  </span>
                </div>
                <h3 class="mb-1 fw-bold text-success">
                  {{ user.active_status }}
                </h3>
                <p class="mb-0 text-muted small">Status Contributions</p>
              </BCard>
            </BCol>
          </BRow>

          <!-- Profile Details Card -->
          <BCard class="border-0 shadow-sm mb-4">
            <BCardBody>
              <h6 class="text-muted fw-semibold mb-3 d-flex align-items-center">
                <i class="bi bi-person-lines-fill me-2" />
                Profile Details
              </h6>

              <div class="profile-details">
                <div class="detail-row">
                  <div class="detail-icon">
                    <i class="bi bi-at text-muted" />
                  </div>
                  <div class="detail-content">
                    <span class="detail-label">Username</span>
                    <span class="detail-value">{{ user.user_name[0] }}</span>
                  </div>
                </div>

                <div class="detail-row">
                  <div class="detail-icon">
                    <i class="bi bi-envelope text-muted" />
                  </div>
                  <div class="detail-content">
                    <span class="detail-label">Email</span>
                    <span class="detail-value">{{ user.email[0] }}</span>
                  </div>
                </div>

                <div class="detail-row">
                  <div class="detail-icon">
                    <i class="bi bi-link-45deg text-muted" />
                  </div>
                  <div class="detail-content">
                    <span class="detail-label">ORCID</span>
                    <a
                      v-if="user.orcid[0]"
                      :href="'https://orcid.org/' + user.orcid[0]"
                      target="_blank"
                      class="detail-value text-decoration-none"
                    >
                      <i class="bi bi-box-arrow-up-right me-1" style="font-size: 0.75rem" />
                      {{ user.orcid[0] }}
                    </a>
                    <span v-else class="detail-value text-muted">Not provided</span>
                  </div>
                </div>

                <div class="detail-row">
                  <div class="detail-icon">
                    <i class="bi bi-hash text-muted" />
                  </div>
                  <div class="detail-content">
                    <span class="detail-label">Abbreviation</span>
                    <span class="detail-value">
                      <BBadge variant="secondary">{{ user.abbreviation[0] }}</BBadge>
                    </span>
                  </div>
                </div>
              </div>
            </BCardBody>
          </BCard>

          <!-- Security Card -->
          <BCard class="border-0 shadow-sm">
            <BCardBody>
              <h6 class="text-muted fw-semibold mb-3 d-flex align-items-center">
                <i class="bi bi-shield-lock me-2" />
                Security & Session
              </h6>

              <!-- Session Info -->
              <div class="session-info p-3 rounded-3 bg-light mb-3">
                <div class="d-flex align-items-center justify-content-between">
                  <div>
                    <div class="d-flex align-items-center gap-2 mb-1">
                      <i class="bi bi-clock-history text-muted" />
                      <span class="small fw-semibold">Auto-logout in</span>
                    </div>
                    <div class="d-flex align-items-center gap-2">
                      <span class="session-timer fw-bold" :class="sessionTimerClass">
                        {{ formatTimeRemaining }}
                      </span>
                    </div>
                  </div>
                  <BButton
                    variant="outline-success"
                    size="sm"
                    class="d-flex align-items-center gap-1"
                    @click="refreshWithJWT"
                  >
                    <i class="bi bi-arrow-repeat" />
                    <span class="d-none d-sm-inline">Refresh</span>
                  </BButton>
                </div>
              </div>

              <!-- Change Password Section -->
              <div class="password-section">
                <BButton
                  variant="outline-secondary"
                  class="w-100 d-flex align-items-center justify-content-between"
                  :class="{ 'mb-3': pass_change_visible }"
                  @click="pass_change_visible = !pass_change_visible"
                >
                  <span class="d-flex align-items-center gap-2">
                    <i class="bi bi-key" />
                    Change Password
                  </span>
                  <i
                    class="bi transition-transform"
                    :class="pass_change_visible ? 'bi-chevron-up' : 'bi-chevron-down'"
                  />
                </BButton>

                <BCollapse id="collapse-pass-change" v-model="pass_change_visible">
                  <div class="password-form p-3 rounded-3 bg-light">
                    <form @submit.prevent="onPasswordSubmit">
                      <BFormGroup class="mb-3">
                        <template #label>
                          <span class="small fw-semibold">Current Password</span>
                        </template>
                        <BFormInput
                          v-model="currentPassword"
                          type="password"
                          size="sm"
                          placeholder="Enter current password"
                          :state="
                            currentPasswordMeta.touched
                              ? currentPasswordError
                                ? false
                                : true
                              : null
                          "
                        />
                        <BFormInvalidFeedback v-if="currentPasswordError">
                          {{ currentPasswordError }}
                        </BFormInvalidFeedback>
                      </BFormGroup>

                      <BFormGroup class="mb-3">
                        <template #label>
                          <span class="small fw-semibold d-flex align-items-center gap-1">
                            New Password
                            <i
                              id="password-help"
                              class="bi bi-question-circle text-muted"
                              style="cursor: help"
                            />
                            <BTooltip target="password-help" triggers="hover" placement="right">
                              Must be 8+ characters with uppercase, lowercase, number, and special
                              character (!@#$%^&*)
                            </BTooltip>
                          </span>
                        </template>
                        <BFormInput
                          v-model="newPasswordEntry"
                          type="password"
                          size="sm"
                          placeholder="Enter new password"
                          :state="
                            newPasswordMeta.touched ? (newPasswordError ? false : true) : null
                          "
                        />
                        <BFormInvalidFeedback v-if="newPasswordError">
                          {{ newPasswordError }}
                        </BFormInvalidFeedback>
                      </BFormGroup>

                      <BFormGroup class="mb-3">
                        <template #label>
                          <span class="small fw-semibold">Confirm New Password</span>
                        </template>
                        <BFormInput
                          v-model="newPasswordRepeat"
                          type="password"
                          size="sm"
                          placeholder="Repeat new password"
                          :state="
                            confirmPasswordMeta.touched
                              ? confirmPasswordError
                                ? false
                                : true
                              : null
                          "
                        />
                        <BFormInvalidFeedback v-if="confirmPasswordError">
                          {{ confirmPasswordError }}
                        </BFormInvalidFeedback>
                      </BFormGroup>

                      <div class="d-flex gap-2">
                        <BButton type="submit" variant="primary" size="sm">
                          <i class="bi bi-check-lg me-1" />
                          Update Password
                        </BButton>
                        <BButton
                          variant="outline-secondary"
                          size="sm"
                          @click="cancelPasswordChange"
                        >
                          Cancel
                        </BButton>
                      </div>
                    </form>
                  </div>
                </BCollapse>
              </div>
            </BCardBody>
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useForm, useField, defineRule } from 'vee-validate';
import { required, min, max, confirmed } from '@vee-validate/rules';
import { useToast, useColorAndSymbols } from '@/composables';

// Define validation rules globally
defineRule('required', required);
defineRule('min', min);
defineRule('max', max);
defineRule('confirmed', confirmed);

// Custom password complexity rule
defineRule('password_complexity', (value) => {
  if (!value) return true;
  const regex = /(?=.*[!@#$%^&*])(?=.*[A-Z])(?=.*[a-z])(?=.*[\d])/;
  if (!regex.test(value)) {
    return 'Password must contain at least one uppercase, one lowercase, one number, and one special character (!@#$%^&*)';
  }
  return true;
});

export default {
  name: 'UserView',
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();

    // Setup form validation with vee-validate 4
    const { handleSubmit, resetForm } = useForm();

    // Define fields with validation
    const {
      value: currentPassword,
      errorMessage: currentPasswordError,
      meta: currentPasswordMeta,
    } = useField('current_password', 'required|min:5|max:50');

    const {
      value: newPasswordEntry,
      errorMessage: newPasswordError,
      meta: newPasswordMeta,
    } = useField('new_password', 'required|min:8|max:50|password_complexity');

    const {
      value: newPasswordRepeat,
      errorMessage: confirmPasswordError,
      meta: confirmPasswordMeta,
    } = useField('confirm_password', 'required|min:8|max:50|confirmed:@new_password');

    return {
      makeToast,
      ...colorAndSymbols,
      handleSubmit,
      resetForm,
      currentPassword,
      currentPasswordError,
      currentPasswordMeta,
      newPasswordEntry,
      newPasswordError,
      newPasswordMeta,
      newPasswordRepeat,
      confirmPasswordError,
      confirmPasswordMeta,
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
    };
  },
  computed: {
    roleVariant() {
      const variants = {
        Administrator: 'danger',
        Curator: 'primary',
        Reviewer: 'info',
        Viewer: 'secondary',
      };
      return variants[this.user.user_role[0]] || 'secondary';
    },
    roleIcon() {
      const icons = {
        Administrator: 'shield-fill-check',
        Curator: 'pencil-fill',
        Reviewer: 'eye-fill',
        Viewer: 'person-fill',
      };
      return icons[this.user.user_role[0]] || 'person-fill';
    },
    sessionStatusClass() {
      if (this.time_to_logout > 30) return 'bg-success-subtle text-success';
      if (this.time_to_logout > 10) return 'bg-warning-subtle text-warning';
      return 'bg-danger-subtle text-danger';
    },
    sessionStatusText() {
      if (this.time_to_logout > 30) return 'Active';
      if (this.time_to_logout > 10) return 'Expiring soon';
      return 'Expires soon';
    },
    sessionTimerClass() {
      if (this.time_to_logout > 30) return 'text-success';
      if (this.time_to_logout > 10) return 'text-warning';
      return 'text-danger';
    },
    formatTimeRemaining() {
      const minutes = Math.floor(this.time_to_logout);
      const seconds = Math.floor((this.time_to_logout - minutes) * 60);
      return `${minutes}m ${seconds}s`;
    },
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
    formatDate(dateString) {
      if (!dateString) return '—';
      const date = new Date(dateString);
      return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      });
    },
    onPasswordSubmit() {
      this.handleSubmit(() => {
        this.changePassword();
      })();
    },
    cancelPasswordChange() {
      this.pass_change_visible = false;
      this.resetPasswordForm();
    },
    updateDiffs() {
      if (localStorage.token) {
        const expires = JSON.parse(localStorage.user).exp;
        const timestamp = Math.floor(new Date().getTime() / 1000);
        this.time_to_logout = ((expires - timestamp) / 60).toFixed(2);
      }
    },
    async getUserContributions() {
      const apiContributionsURL = `${import.meta.env.VITE_API_URL}/api/user/${this.user.user_id[0]}/contributions`;

      try {
        const response_contributions = await this.axios.get(apiContributionsURL, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        [this.user.active_reviews] = response_contributions.data.active_reviews;
        [this.user.active_status] = response_contributions.data.active_status;
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
        this.makeToast('Session refreshed successfully', 'Success', 'success');
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
        this.user = response_signin.data;
        this.updateDiffs();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async changePassword() {
      const apiChangePasswordURL = `${import.meta.env.VITE_API_URL}/api/user/password/update?user_id_pass_change=${this.user.user_id[0]}&old_pass=${this.currentPassword}&new_pass_1=${this.newPasswordEntry}&new_pass_2=${this.newPasswordRepeat}`;
      try {
        const response_password_change = await this.axios.put(
          apiChangePasswordURL,
          {},
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          }
        );
        this.makeToast(
          `${response_password_change.data.message} (status ${response_password_change.status})`,
          'Success',
          'success'
        );
        this.pass_change_visible = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.pass_change_visible = false;
      }
      this.resetPasswordForm();
    },
    resetPasswordForm() {
      this.resetForm();
    },
  },
};
</script>

<style scoped>
/* Profile Header */
.profile-header-bg {
  height: 80px;
  margin: -1rem -1rem 0 -1rem;
}

.profile-identity {
  margin-top: -40px;
}

/* Avatar Styling */
.avatar-wrapper {
  position: relative;
  flex-shrink: 0;
}

.avatar-circle {
  width: 96px;
  height: 96px;
  border-radius: 50%;
  border: 4px solid white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.avatar-initials {
  font-size: 2rem;
  font-weight: 700;
  letter-spacing: 1px;
}

.avatar-badge {
  position: absolute;
  bottom: 4px;
  right: 4px;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  border: 2px solid white;
  color: white;
  font-size: 0.75rem;
}

/* Stats Cards */
.stat-card {
  transition:
    transform 0.2s ease,
    box-shadow 0.2s ease;
}

.stat-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1) !important;
}

.stat-icon span {
  width: 48px;
  height: 48px;
  font-size: 1.25rem;
}

/* Profile Details */
.profile-details {
  display: flex;
  flex-direction: column;
  gap: 0;
}

.detail-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 0;
  border-bottom: 1px solid #f0f0f0;
}

.detail-row:last-child {
  border-bottom: none;
}

.detail-icon {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1rem;
  flex-shrink: 0;
}

.detail-content {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.detail-label {
  font-size: 0.75rem;
  color: #6c757d;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.detail-value {
  font-size: 0.95rem;
  color: #212529;
  word-break: break-word;
}

/* Session Info */
.session-timer {
  font-size: 1.25rem;
  font-variant-numeric: tabular-nums;
}

/* Password Form */
.password-form {
  border: 1px solid #e9ecef;
}

/* Transitions */
.transition-transform {
  transition: transform 0.2s ease;
}

/* Responsive */
@media (max-width: 575.98px) {
  .avatar-circle {
    width: 80px;
    height: 80px;
  }

  .avatar-initials {
    font-size: 1.5rem;
  }

  .avatar-badge {
    width: 24px;
    height: 24px;
    font-size: 0.65rem;
  }

  .profile-identity {
    margin-top: -32px;
  }

  .stat-icon span {
    width: 40px;
    height: 40px;
    font-size: 1rem;
  }

  .stat-card h3 {
    font-size: 1.5rem;
  }
}
</style>
