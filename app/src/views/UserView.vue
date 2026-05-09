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
  <AuthenticatedPageShell
    title="User profile"
    description="Manage your SysNDD profile, contribution summary, and session security."
    :meta="user.user_role[0] || 'User'"
    content-class="user-profile-page"
  >
    <UserProfileHeader
      :user="user"
      :role-variant="roleVariant"
      :role-icon="roleIcon"
      :member-since="formatDate(user.user_created[0])"
      :session-status-class="sessionStatusClass"
      :session-status-text="sessionStatusText"
    />

    <UserContributionStats
      :active-reviews="activeReviewsCount"
      :active-status="activeStatusCount"
    />

    <div class="user-profile-grid">
      <UserProfileDetails
        :user="user"
        :is-editing="isEditingProfile"
        :is-saving="isSavingProfile"
        :email="editForm.email"
        :orcid="editForm.orcid"
        :email-error="emailError"
        :orcid-error="orcidError"
        :email-validation-state="emailValidationState"
        :orcid-validation-state="orcidValidationState"
        @edit="startEditProfile"
        @save="saveProfile"
        @cancel="cancelEditProfile"
        @update:email="editForm.email = $event"
        @update:orcid="editForm.orcid = $event"
      />

      <UserSecurityPanel
        :time-remaining="formatTimeRemaining"
        :session-timer-class="sessionTimerClass"
        :password-visible="pass_change_visible"
        :current-password="currentPassword"
        :new-password="newPasswordEntry"
        :confirm-password="newPasswordRepeat"
        :current-password-error="currentPasswordError"
        :new-password-error="newPasswordError"
        :confirm-password-error="confirmPasswordError"
        :current-password-state="currentPasswordState"
        :new-password-state="newPasswordState"
        :confirm-password-state="confirmPasswordState"
        @refresh="refreshWithJWT"
        @toggle-password="pass_change_visible = !pass_change_visible"
        @submit-password="onPasswordSubmit"
        @cancel-password="cancelPasswordChange"
        @update:current-password="currentPassword = $event"
        @update:new-password="newPasswordEntry = $event"
        @update:confirm-password="newPasswordRepeat = $event"
      />
    </div>
  </AuthenticatedPageShell>
</template>

<script>
import { useForm, useField, defineRule } from 'vee-validate';
import { required, min, max, confirmed } from '@vee-validate/rules';
import { useToast, useColorAndSymbols } from '@/composables';
import { useAuth } from '@/composables/useAuth';
import { signin, changePassword } from '@/api/auth';
import { getUserContributions, updateProfile } from '@/api/user';
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import UserContributionStats from '@/views/user/UserContributionStats.vue';
import UserProfileDetails from '@/views/user/UserProfileDetails.vue';
import UserProfileHeader from '@/views/user/UserProfileHeader.vue';
import UserSecurityPanel from '@/views/user/UserSecurityPanel.vue';

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
  components: {
    AuthenticatedPageShell,
    UserContributionStats,
    UserProfileDetails,
    UserProfileHeader,
    UserSecurityPanel,
  },
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();
    // Phase E.E7: shared auth state — replaces every direct localStorage
    // read in this view (user payload, expiry, Bearer header).
    const auth = useAuth();

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
      auth,
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
      // Profile editing state
      isEditingProfile: false,
      isSavingProfile: false,
      editForm: {
        email: '',
        orcid: '',
      },
      emailError: null,
      orcidError: null,
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
    activeReviewsCount() {
      return Number(this.user.active_reviews ?? 0);
    },
    activeStatusCount() {
      return Number(this.user.active_status ?? 0);
    },
    currentPasswordState() {
      return this.passwordFieldState(this.currentPasswordMeta, this.currentPasswordError);
    },
    newPasswordState() {
      return this.passwordFieldState(this.newPasswordMeta, this.newPasswordError);
    },
    confirmPasswordState() {
      return this.passwordFieldState(this.confirmPasswordMeta, this.confirmPasswordError);
    },
    emailValidationState() {
      if (!this.isEditingProfile) return null;
      if (this.emailError) return false;
      if (this.editForm.email && this.isValidEmail(this.editForm.email)) return true;
      return null;
    },
    orcidValidationState() {
      if (!this.isEditingProfile) return null;
      if (this.orcidError) return false;
      // Empty is valid (clears ORCID)
      if (!this.editForm.orcid || this.editForm.orcid.trim() === '') return null;
      if (this.isValidOrcid(this.editForm.orcid)) return true;
      return false;
    },
  },
  mounted() {
    // Hydrate the view from the shared auth state (already parsed + guarded
    // against corrupt localStorage.user by `useAuth`). If the composable
    // reports no user (e.g. a route-guard race or cleared state), skip the
    // subsequent calls rather than hitting the API with a stale token.
    const authUser = this.auth.user.value;
    if (authUser) {
      this.user = { ...authUser };

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
    passwordFieldState(meta, error) {
      return meta?.touched ? (error ? false : true) : null;
    },
    cancelPasswordChange() {
      this.pass_change_visible = false;
      this.resetPasswordForm();
    },
    updateDiffs() {
      const authUser = this.auth.user.value;
      if (!this.auth.isAuthenticated.value || !authUser) {
        return;
      }
      const expires = authUser.exp?.[0];
      if (typeof expires !== 'number') {
        return;
      }
      const timestamp = Math.floor(Date.now() / 1000);
      this.time_to_logout = ((expires - timestamp) / 60).toFixed(2);
    },
    async getUserContributions() {
      // `useAuth` already seeded the axios default Authorization header, so
      // per-request Bearer overrides are no longer needed here.
      try {
        const contributions = await getUserContributions(this.user.user_id[0]);
        [this.user.active_reviews] = contributions.active_reviews;
        [this.user.active_status] = contributions.active_status;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async refreshWithJWT() {
      try {
        // `auth.refresh()` owns the /api/auth/refresh call, stores the new
        // token, and re-seeds the axios default Authorization header.
        await this.auth.refresh();
        await this.signinWithJWT();
        this.makeToast('Session refreshed successfully', 'Success', 'success');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async signinWithJWT() {
      try {
        const userPayload = await signin();
        // Persist the refreshed user payload via the composable so every
        // subscriber (navbar, countdown badge, route guards) sees the new
        // `exp` immediately.
        const token = this.auth.token.value;
        if (token) {
          this.auth.login(token, userPayload);
        }
        this.user = { ...userPayload };
        this.updateDiffs();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async changePassword() {
      // OWASP: password fields MUST go in the JSON body, never in URL query
      // params (query strings leak into access logs, Traefik logs, and browser
      // history). The API handler `@put password/update` in
      // api/endpoints/user_endpoints.R accepts both forms during the Phase A
      // hotfix rollout; the JSON body variant is the only one we send.
      try {
        // `useAuth` keeps the axios default Authorization header current;
        // no per-request override needed.
        await changePassword({
          user_id_pass_change: this.user.user_id[0],
          old_pass: this.currentPassword,
          new_pass_1: this.newPasswordEntry,
          new_pass_2: this.newPasswordRepeat,
        });
        this.makeToast('Password changed successfully.', 'Success', 'success');
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
    // Profile editing methods
    startEditProfile() {
      this.editForm.email = this.user.email[0] || '';
      this.editForm.orcid = this.user.orcid[0] || '';
      this.emailError = null;
      this.orcidError = null;
      this.isEditingProfile = true;
    },
    cancelEditProfile() {
      this.isEditingProfile = false;
      this.editForm.email = '';
      this.editForm.orcid = '';
      this.emailError = null;
      this.orcidError = null;
    },
    isValidEmail(email) {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      return emailRegex.test(email);
    },
    isValidOrcid(orcid) {
      // ORCID format: 0000-0000-0000-000X (last char can be digit or X)
      const orcidRegex = /^\d{4}-\d{4}-\d{4}-\d{3}[\dX]$/i;
      return orcidRegex.test(orcid);
    },
    async saveProfile() {
      // Reset errors
      this.emailError = null;
      this.orcidError = null;

      // Validate email
      if (!this.editForm.email || !this.editForm.email.trim()) {
        this.emailError = 'Email is required.';
        return;
      }
      if (!this.isValidEmail(this.editForm.email)) {
        this.emailError = 'Please enter a valid email address.';
        return;
      }

      // Validate ORCID (if provided)
      const orcidTrimmed = this.editForm.orcid ? this.editForm.orcid.trim() : '';
      if (orcidTrimmed && !this.isValidOrcid(orcidTrimmed)) {
        this.orcidError = 'Invalid ORCID format. Expected: 0000-0000-0000-000X';
        return;
      }

      // Check if anything changed
      const emailChanged = this.editForm.email.trim() !== (this.user.email[0] || '');
      const orcidChanged = orcidTrimmed !== (this.user.orcid[0] || '');

      if (!emailChanged && !orcidChanged) {
        this.makeToast('No changes detected.', 'Info', 'info');
        this.isEditingProfile = false;
        return;
      }

      // Save profile
      this.isSavingProfile = true;

      try {
        const payload = {};
        if (emailChanged) payload.email = this.editForm.email.trim();
        if (orcidChanged) payload.orcid = orcidTrimmed;

        const response = await updateProfile(payload, {
          headers: {
            'Content-Type': 'application/json',
          },
        });

        // Update local user data
        if (emailChanged) {
          this.user.email = [this.editForm.email.trim()];
        }
        if (orcidChanged) {
          this.user.orcid = [orcidTrimmed];
        }

        // Persist the updated profile through `useAuth` so the navbar and
        // other observers see the new email/ORCID without a page refresh.
        const token = this.auth.token.value;
        if (token) {
          this.auth.login(token, this.user);
        }

        this.makeToast(
          `Profile updated successfully. ${response.updated_fields?.join(', ') || ''}`,
          'Success',
          'success'
        );
        this.isEditingProfile = false;
      } catch (e) {
        const errorMessage = e.response?.data?.error || e.message || 'Failed to update profile.';
        this.makeToast(errorMessage, 'Error', 'danger');
      } finally {
        this.isSavingProfile = false;
      }
    },
  },
};
</script>

<style scoped>
.user-profile-page {
  display: grid;
  gap: 0.9rem;
  background: #fbfcfe;
}

.user-profile-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(22rem, 0.85fr);
  gap: 0.9rem;
  align-items: start;
}

@media (max-width: 991.98px) {
  .user-profile-grid {
    grid-template-columns: 1fr;
  }
}
</style>
