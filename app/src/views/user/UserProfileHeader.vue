<template>
  <section class="profile-card profile-header-card">
    <div class="profile-header-bg" :class="`bg-${roleVariant}-subtle`" />
    <div class="profile-identity">
      <div class="avatar-wrapper">
        <div
          class="avatar-circle d-flex align-items-center justify-content-center"
          :class="`bg-${roleVariant} text-white`"
        >
          <span class="avatar-initials">{{ user.abbreviation?.[0] || '?' }}</span>
        </div>
        <span
          class="avatar-badge d-flex align-items-center justify-content-center"
          :class="`bg-${roleVariant}`"
        >
          <i :class="`bi bi-${roleIcon}`" aria-hidden="true" />
        </span>
      </div>

      <div class="profile-identity-copy">
        <h2>{{ user.user_name?.[0] || 'User' }}</h2>
        <div class="profile-meta">
          <BBadge :variant="roleVariant" class="d-inline-flex align-items-center gap-1">
            <i :class="`bi bi-${roleIcon}`" aria-hidden="true" />
            {{ user.user_role?.[0] || 'User' }}
          </BBadge>
          <span class="text-muted small">
            <i class="bi bi-calendar3 me-1" aria-hidden="true" />
            Member since {{ memberSince }}
          </span>
        </div>
      </div>

      <div class="session-badge">
        <span class="session-pill" :class="sessionStatusClass">
          <i class="bi bi-circle-fill" aria-hidden="true" />
          <span>{{ sessionStatusText }}</span>
        </span>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
interface UserProfileSummary {
  abbreviation?: string[];
  user_name?: string[];
  user_role?: string[];
}

type BootstrapVariant =
  | 'primary'
  | 'secondary'
  | 'success'
  | 'danger'
  | 'warning'
  | 'info'
  | 'light'
  | 'dark';

defineProps<{
  user: UserProfileSummary;
  roleVariant: BootstrapVariant;
  roleIcon: string;
  memberSince: string;
  sessionStatusClass: string;
  sessionStatusText: string;
}>();
</script>

<style scoped>
.profile-card {
  overflow: hidden;
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.08);
}

.profile-header-bg {
  height: 74px;
}

.profile-identity {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: end;
  gap: 1rem;
  padding: 0 1.35rem 1.1rem;
  margin-top: -38px;
}

.avatar-wrapper {
  position: relative;
  flex-shrink: 0;
}

.avatar-circle {
  width: 92px;
  height: 92px;
  border: 4px solid #fff;
  border-radius: 50%;
  box-shadow: 0 2px 8px rgba(15, 23, 42, 0.14);
}

.avatar-initials {
  font-size: 1.85rem;
  font-weight: 750;
  letter-spacing: 0;
}

.avatar-badge {
  position: absolute;
  right: 4px;
  bottom: 4px;
  width: 28px;
  height: 28px;
  border: 2px solid #fff;
  border-radius: 50%;
  color: #fff;
  font-size: 0.75rem;
}

.profile-identity-copy {
  min-width: 0;
  padding-bottom: 0.3rem;
  text-align: left;
}

.profile-identity-copy h2 {
  margin: 0 0 0.3rem;
  color: #172033;
  font-size: 1.25rem;
  font-weight: 750;
  line-height: 1.2;
}

.profile-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
}

.session-badge {
  padding-bottom: 0.45rem;
}

.session-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  min-height: 1.75rem;
  padding: 0.25rem 0.65rem;
  border-radius: 999px;
  font-size: 0.82rem;
  font-weight: 700;
  white-space: nowrap;
}

.session-pill .bi {
  font-size: 0.5rem;
}

@media (max-width: 575.98px) {
  .profile-identity {
    grid-template-columns: 1fr;
    justify-items: center;
    gap: 0.55rem;
    padding: 0 0.9rem 1rem;
    text-align: center;
  }

  .profile-identity-copy {
    padding-bottom: 0;
    text-align: center;
  }

  .profile-meta {
    justify-content: center;
  }

  .session-badge {
    padding-bottom: 0;
  }
}
</style>
