<template>
  <section class="profile-card">
    <header class="profile-card__header">
      <h2><i class="bi bi-shield-lock" aria-hidden="true" /> Security & Session</h2>
    </header>

    <div class="security-body">
      <div class="session-info">
        <div>
          <div class="session-label">
            <i class="bi bi-clock-history" aria-hidden="true" />
            Auto-logout in
          </div>
          <span class="session-timer" :class="sessionTimerClass">{{ timeRemaining }}</span>
        </div>
        <BButton
          variant="outline-success"
          size="sm"
          class="d-inline-flex align-items-center gap-1"
          @click="$emit('refresh')"
        >
          <i class="bi bi-arrow-repeat" aria-hidden="true" />
          Refresh
        </BButton>
      </div>

      <BButton
        variant="outline-secondary"
        class="w-100 d-flex align-items-center justify-content-between"
        :class="{ 'mb-3': passwordVisible }"
        @click="$emit('toggle-password')"
      >
        <span class="d-flex align-items-center gap-2">
          <i class="bi bi-key" aria-hidden="true" />
          Change Password
        </span>
        <i
          class="bi transition-transform"
          :class="passwordVisible ? 'bi-chevron-up' : 'bi-chevron-down'"
          aria-hidden="true"
        />
      </BButton>

      <BCollapse id="collapse-pass-change" :model-value="passwordVisible">
        <div class="password-form">
          <form @submit.prevent="$emit('submit-password')">
            <BFormGroup class="mb-3">
              <template #label><span class="small fw-semibold">Current Password</span></template>
              <BFormInput
                :model-value="currentPassword"
                type="password"
                size="sm"
                placeholder="Enter current password"
                :state="currentPasswordState"
                @update:model-value="$emit('update:currentPassword', String($event ?? ''))"
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
                    aria-hidden="true"
                  />
                  <BTooltip target="password-help" triggers="hover" placement="right">
                    Must be 8+ characters with uppercase, lowercase, number, and special character
                    (!@#$%^&*)
                  </BTooltip>
                </span>
              </template>
              <BFormInput
                :model-value="newPassword"
                type="password"
                size="sm"
                placeholder="Enter new password"
                :state="newPasswordState"
                @update:model-value="$emit('update:newPassword', String($event ?? ''))"
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
                :model-value="confirmPassword"
                type="password"
                size="sm"
                placeholder="Repeat new password"
                :state="confirmPasswordState"
                @update:model-value="$emit('update:confirmPassword', String($event ?? ''))"
              />
              <BFormInvalidFeedback v-if="confirmPasswordError">
                {{ confirmPasswordError }}
              </BFormInvalidFeedback>
            </BFormGroup>

            <div class="d-flex flex-wrap gap-2">
              <BButton type="submit" variant="primary" size="sm">
                <i class="bi bi-check-lg me-1" aria-hidden="true" />
                Update Password
              </BButton>
              <BButton variant="outline-secondary" size="sm" @click="$emit('cancel-password')">
                Cancel
              </BButton>
            </div>
          </form>
        </div>
      </BCollapse>
    </div>
  </section>
</template>

<script setup lang="ts">
defineProps<{
  timeRemaining: string;
  sessionTimerClass: string;
  passwordVisible: boolean;
  currentPassword?: string;
  newPassword?: string;
  confirmPassword?: string;
  currentPasswordError?: string;
  newPasswordError?: string;
  confirmPasswordError?: string;
  currentPasswordState?: boolean | null;
  newPasswordState?: boolean | null;
  confirmPasswordState?: boolean | null;
}>();

defineEmits<{
  (event: 'refresh'): void;
  (event: 'toggle-password'): void;
  (event: 'submit-password'): void;
  (event: 'cancel-password'): void;
  (event: 'update:currentPassword', value: string): void;
  (event: 'update:newPassword', value: string): void;
  (event: 'update:confirmPassword', value: string): void;
}>();
</script>

<style scoped>
.profile-card {
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.08);
}

.profile-card__header {
  padding: 0.8rem 0.9rem;
  border-bottom: 1px solid #e6ebf2;
}

.profile-card__header h2 {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  margin: 0;
  color: #526070;
  font-size: 0.95rem;
  font-weight: 750;
}

.security-body {
  display: grid;
  gap: 0.85rem;
  padding: 0.9rem;
}

.session-info {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.85rem;
  border: 1px solid #e6ebf2;
  border-radius: 8px;
  background: #f8fafc;
}

.session-label {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  color: #526070;
  font-size: 0.82rem;
  font-weight: 650;
}

.session-timer {
  font-size: 1.2rem;
  font-variant-numeric: tabular-nums;
  font-weight: 750;
}

.password-form {
  padding: 0.9rem;
  border: 1px solid #e6ebf2;
  border-radius: 8px;
  background: #f8fafc;
}

.transition-transform {
  transition: transform 0.2s ease;
}

@media (max-width: 575.98px) {
  .session-info {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
