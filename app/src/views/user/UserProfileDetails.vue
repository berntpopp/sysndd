<template>
  <section class="profile-card">
    <header class="profile-card__header">
      <h2><i class="bi bi-person-lines-fill" aria-hidden="true" /> Profile Details</h2>
      <BButton
        v-if="!isEditing"
        variant="outline-primary"
        size="sm"
        class="d-inline-flex align-items-center gap-1"
        @click="$emit('edit')"
      >
        <i class="bi bi-pencil" aria-hidden="true" />
        Edit
      </BButton>
      <div v-else class="profile-actions">
        <BButton
          variant="primary"
          size="sm"
          class="d-inline-flex align-items-center gap-1"
          :disabled="isSaving"
          @click="$emit('save')"
        >
          <BSpinner v-if="isSaving" small />
          <i v-else class="bi bi-check-lg" aria-hidden="true" />
          Save
        </BButton>
        <BButton
          variant="outline-secondary"
          size="sm"
          :disabled="isSaving"
          @click="$emit('cancel')"
        >
          Cancel
        </BButton>
      </div>
    </header>

    <div class="profile-details">
      <div class="detail-row">
        <div class="detail-icon"><i class="bi bi-at" aria-hidden="true" /></div>
        <div class="detail-content">
          <span class="detail-label">Username</span>
          <span class="detail-value">{{ user.user_name?.[0] }}</span>
        </div>
      </div>

      <div class="detail-row">
        <div class="detail-icon"><i class="bi bi-envelope" aria-hidden="true" /></div>
        <div class="detail-content">
          <span class="detail-label">Email</span>
          <template v-if="isEditing">
            <BFormInput
              :model-value="email"
              type="email"
              size="sm"
              placeholder="Enter email address"
              :state="emailValidationState"
              class="mt-1"
              @update:model-value="$emit('update:email', String($event ?? ''))"
            />
            <BFormInvalidFeedback v-if="emailError">{{ emailError }}</BFormInvalidFeedback>
          </template>
          <span v-else class="detail-value">{{ user.email?.[0] }}</span>
        </div>
      </div>

      <div class="detail-row">
        <div class="detail-icon"><i class="bi bi-link-45deg" aria-hidden="true" /></div>
        <div class="detail-content">
          <span class="detail-label d-flex align-items-center gap-1">
            ORCID
            <i v-if="isEditing" id="orcid-help" class="bi bi-question-circle" aria-hidden="true" />
            <BTooltip v-if="isEditing" target="orcid-help" triggers="hover" placement="right">
              Format: 0000-0000-0000-000X (16 digits with dashes)
            </BTooltip>
          </span>
          <template v-if="isEditing">
            <BFormInput
              :model-value="orcid"
              type="text"
              size="sm"
              placeholder="0000-0000-0000-0000"
              :state="orcidValidationState"
              class="mt-1"
              @update:model-value="$emit('update:orcid', String($event ?? ''))"
            />
            <BFormInvalidFeedback v-if="orcidError">{{ orcidError }}</BFormInvalidFeedback>
            <BFormText v-else class="text-muted"> Leave empty to remove ORCID </BFormText>
          </template>
          <template v-else>
            <a
              v-if="user.orcid?.[0]"
              :href="`https://orcid.org/${user.orcid[0]}`"
              target="_blank"
              rel="noopener"
              class="detail-value text-decoration-none"
            >
              <i class="bi bi-box-arrow-up-right me-1" aria-hidden="true" />
              {{ user.orcid[0] }}
            </a>
            <span v-else class="detail-value text-muted">Not provided</span>
          </template>
        </div>
      </div>

      <div class="detail-row">
        <div class="detail-icon"><i class="bi bi-hash" aria-hidden="true" /></div>
        <div class="detail-content">
          <span class="detail-label">Abbreviation</span>
          <span class="detail-value">
            <BBadge variant="secondary">{{ user.abbreviation?.[0] }}</BBadge>
          </span>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
interface UserProfileDetailsUser {
  user_name?: string[];
  email?: string[];
  orcid?: string[];
  abbreviation?: string[];
}

defineProps<{
  user: UserProfileDetailsUser;
  isEditing: boolean;
  isSaving: boolean;
  email: string;
  orcid: string;
  emailError?: string | null;
  orcidError?: string | null;
  emailValidationState?: boolean | null;
  orcidValidationState?: boolean | null;
}>();

defineEmits<{
  (event: 'edit'): void;
  (event: 'save'): void;
  (event: 'cancel'): void;
  (event: 'update:email', value: string): void;
  (event: 'update:orcid', value: string): void;
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
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
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

.profile-actions {
  display: inline-flex;
  gap: 0.4rem;
}

.profile-details {
  padding: 0.35rem 0.9rem;
}

.detail-row {
  display: grid;
  grid-template-columns: 2rem minmax(0, 1fr);
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 0;
  border-bottom: 1px solid #edf1f6;
}

.detail-row:last-child {
  border-bottom: 0;
}

.detail-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: #64748b;
}

.detail-content {
  display: grid;
  min-width: 0;
}

.detail-label {
  color: #64748b;
  font-size: 0.72rem;
  font-weight: 650;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}

.detail-value {
  color: #172033;
  font-size: 0.92rem;
  word-break: break-word;
}
</style>
