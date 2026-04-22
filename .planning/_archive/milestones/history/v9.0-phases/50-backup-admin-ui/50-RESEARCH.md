# Phase 50: Backup Admin UI - Research

**Researched:** 2026-01-29
**Domain:** Vue 3 admin interface for backup management
**Confidence:** HIGH

## Summary

This phase implements an admin UI for managing database backups through the existing admin panel. The Phase 49 API layer is complete, providing endpoints for listing backups (`GET /api/backup/list`), creating backups (`POST /api/backup/create`), and restoring (`POST /api/backup/restore`). The UI needs to display a backup list with download capability, trigger manual backups with async job polling, and implement a type-to-confirm restore modal.

The codebase has established patterns for admin views (ManageUser.vue, ManageAnnotations.vue), async job tracking (useAsyncJob composable), and Bootstrap-Vue-Next components. The implementation follows Vue 3 Composition API with `<script setup>` for new components.

**Primary recommendation:** Create a new `ManageBackups.vue` view following the ManageAnnotations.vue pattern, using the existing `useAsyncJob` composable for backup/restore progress tracking, and implementing the type-to-confirm pattern using a disabled button that enables only when input matches "RESTORE" exactly.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.x | Reactive UI framework | Already used, Composition API preferred |
| Bootstrap-Vue-Next | latest | UI component library | Already used across all admin views |
| Axios | 0.21.4 | HTTP client | Already configured with auth headers |
| useAsyncJob | local | Job polling composable | Already used in ManageAnnotations.vue |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| useToast | local | Toast notifications | Success/error feedback |
| file-saver | 2.0.5 | File downloads | If native blob download fails |
| @vueuse/core | latest | Utility composables | Already used for useIntervalFn |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom job polling | useAsyncJob | Composable already handles cleanup, elapsed time |
| Custom download | file-saver | Native blob download works for most browsers |
| Custom modal | BModal | Bootstrap modal has built-in ok/cancel patterns |

**Installation:**
No new packages required - all dependencies already in package.json.

## Architecture Patterns

### Recommended Project Structure
```
app/src/
├── views/admin/
│   └── ManageBackups.vue        # New: Main backup admin view
├── composables/
│   └── useAsyncJob.ts           # Existing: Job polling
└── router/routes.ts             # Add: /ManageBackups route
```

### Pattern 1: Admin View with Async Job Tracking
**What:** Use ManageAnnotations.vue as template for combining list display with async operations
**When to use:** Any admin view with long-running operations
**Example:**
```vue
<!-- Source: ManageAnnotations.vue pattern -->
<script setup lang="ts">
import { ref, onMounted, watch } from 'vue';
import axios from 'axios';
import useToast from '@/composables/useToast';
import { useAsyncJob } from '@/composables/useAsyncJob';

const { makeToast } = useToast();

// Create job instance for backup operations
const backupJob = useAsyncJob(
  (jobId: string) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`
);

// Watch for job completion
watch(
  () => backupJob.status.value,
  (newStatus) => {
    if (newStatus === 'completed') {
      makeToast('Backup created successfully', 'Success', 'success');
      fetchBackupList(); // Refresh list
    } else if (newStatus === 'failed') {
      makeToast(backupJob.error.value || 'Backup failed', 'Error', 'danger');
    }
  }
);
</script>
```

### Pattern 2: Type-to-Confirm Dangerous Action Modal
**What:** Require exact text input before enabling destructive action button
**When to use:** Database restore (per BKUP-04 requirement)
**Example:**
```vue
<!-- Source: ManageUser.vue bulk delete pattern + UX best practices -->
<BModal
  v-model="showRestoreModal"
  title="Restore Database"
  ok-variant="danger"
  ok-title="Restore"
  :ok-disabled="restoreConfirmText !== 'RESTORE'"
  @ok="confirmRestore"
>
  <p class="text-danger fw-bold">
    This will overwrite the current database. Type RESTORE to confirm.
  </p>
  <BFormInput
    v-model="restoreConfirmText"
    placeholder="RESTORE"
    autocomplete="off"
  />
</BModal>

<script setup>
const restoreConfirmText = ref('');
const showRestoreModal = ref(false);

function confirmRestore() {
  restoreConfirmText.value = ''; // Reset for next time
  // Start restore job...
}
</script>
```

### Pattern 3: Blob Download for Backup Files
**What:** Download backup files using axios blob responseType
**When to use:** Download button for each backup row
**Example:**
```typescript
// Source: TablesLogs.vue download pattern + Vue download best practices
async function downloadBackup(filename: string) {
  try {
    const response = await axios({
      url: `${import.meta.env.VITE_API_URL}/api/backup/download/${filename}`,
      method: 'GET',
      responseType: 'blob',
      headers: {
        Authorization: `Bearer ${localStorage.getItem('token')}`,
      },
    });

    const url = window.URL.createObjectURL(new Blob([response.data]));
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', filename);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.URL.revokeObjectURL(url);
  } catch (error) {
    makeToast('Download failed', 'Error', 'danger');
  }
}
```

### Pattern 4: Human-Readable File Sizes
**What:** Format bytes to human-readable strings
**When to use:** Displaying backup file sizes in list
**Example:**
```typescript
// Per CONTEXT.md: "1.2 GB", "458 MB" format
function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}
```

### Anti-Patterns to Avoid
- **No confirmation for restore:** Per BKUP-04, restore MUST require typing "RESTORE" exactly
- **Sync job status polling:** Use useAsyncJob which handles cleanup on unmount
- **Alert/confirm() for dangerous actions:** Use Bootstrap modal with typed confirmation
- **Hard-coded API URLs:** Use import.meta.env.VITE_API_URL

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Job status polling | Custom setInterval | useAsyncJob composable | Handles cleanup, elapsed time, progress |
| Toast notifications | Custom alerts | useToast composable | Consistent styling, error toasts stay visible |
| Modal dialogs | HTML confirm() | BModal component | Styled, accessible, better UX |
| File size formatting | Inline math | Utility function | Reusable, consistent formatting |
| Date formatting | Manual string ops | toLocaleString() or date-fns | Handles timezones, localization |
| Blob downloads | window.open() | Axios blob + createObjectURL | Works with auth headers, progress tracking |

**Key insight:** The existing admin views and composables provide all needed patterns. ManageAnnotations.vue demonstrates job tracking with progress bars, ManageUser.vue shows modal patterns with confirmation inputs.

## Common Pitfalls

### Pitfall 1: Forgetting to Reset Confirmation Input
**What goes wrong:** After restore, modal reopens with "RESTORE" already typed
**Why it happens:** State persists across modal open/close
**How to avoid:** Reset `restoreConfirmText = ''` in both confirm and cancel handlers
**Warning signs:** User can accidentally trigger restore twice

### Pitfall 2: Missing Authorization Header on Download
**What goes wrong:** 401 Unauthorized when downloading backup file
**Why it happens:** Axios defaults don't include auth header for blob requests
**How to avoid:** Explicitly set Authorization header in download request
**Warning signs:** Download works in dev but fails in production

### Pitfall 3: Memory Leak from Unreleased Object URLs
**What goes wrong:** Browser memory usage grows with each download
**Why it happens:** createObjectURL() allocates memory that persists until revoked
**How to avoid:** Always call `URL.revokeObjectURL()` after download triggers
**Warning signs:** Slow browser after multiple downloads

### Pitfall 4: Job Polling Continues After Navigation
**What goes wrong:** Network requests continue after leaving page
**Why it happens:** Custom polling with setInterval not cleaned up
**How to avoid:** Use useAsyncJob which uses VueUse's useIntervalFn with auto-cleanup
**Warning signs:** Console errors after navigating away from backup page

### Pitfall 5: R/Plumber Array Wrapping Not Handled
**What goes wrong:** Display shows `["filename.sql"]` instead of `filename.sql`
**Why it happens:** R/Plumber returns scalars as single-element arrays
**How to avoid:** Use unwrapValue helper pattern from useAsyncJob
**Warning signs:** Arrays displayed where strings expected

## Code Examples

Verified patterns from existing codebase:

### Admin Route with Auth Guard
```typescript
// Source: routes.ts existing admin patterns
{
  path: '/ManageBackups',
  name: 'ManageBackups',
  component: () => import('@/views/admin/ManageBackups.vue'),
  meta: { sitemap: { ignoreRoute: true } },
  beforeEnter: (to, from, next) => {
    const allowed_roles = ['Administrator'];
    let expires = 0;
    let timestamp = 0;
    let user_role = 'Viewer';

    if (localStorage.token) {
      expires = JSON.parse(localStorage.user).exp;
      user_role = JSON.parse(localStorage.user).user_role;
      timestamp = Math.floor(new Date().getTime() / 1000);
    }

    if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) {
      next({ name: 'Login' });
    } else next();
  },
},
```

### Backup List Table Structure
```vue
<!-- Source: ManageAnnotations.vue job history table pattern -->
<BTable
  :items="backups"
  :fields="backupFields"
  :busy="loading"
  striped
  hover
  small
  responsive
>
  <template #cell(filename)="data">
    <span class="font-monospace">{{ data.value }}</span>
  </template>

  <template #cell(size_bytes)="data">
    {{ formatFileSize(data.value) }}
  </template>

  <template #cell(created_at)="data">
    {{ formatDate(data.value) }}
  </template>

  <template #cell(actions)="data">
    <BButton
      size="sm"
      variant="outline-primary"
      class="me-1"
      @click="downloadBackup(data.item.filename)"
    >
      <i class="bi bi-download" />
    </BButton>
    <BButton
      size="sm"
      variant="outline-danger"
      @click="promptRestore(data.item)"
    >
      <i class="bi bi-arrow-counterclockwise" />
    </BButton>
  </template>
</BTable>
```

### Progress Display During Operations
```vue
<!-- Source: ManageAnnotations.vue progress pattern -->
<div v-if="backupJob.isLoading.value || backupJob.status.value !== 'idle'" class="mt-3">
  <div class="d-flex align-items-center mb-2">
    <span class="badge me-2" :class="backupJob.statusBadgeClass.value">
      {{ backupJob.status.value }}
    </span>
    <span class="text-muted">{{ backupJob.step.value }}</span>
  </div>

  <BProgress
    v-if="backupJob.isLoading.value"
    :value="100"
    :max="100"
    :animated="true"
    :striped="true"
    :variant="backupJob.progressVariant.value"
    height="1.5rem"
  >
    <template #default>
      <span>{{ backupStatusLabel }} ({{ backupJob.elapsedTimeDisplay.value }})</span>
    </template>
  </BProgress>
</div>
```

### Unwrap R/Plumber Values
```typescript
// Source: useAsyncJob.ts and ManageAnnotations.vue
function unwrapValue<T>(val: T | T[]): T {
  return Array.isArray(val) && val.length === 1 ? val[0] : (val as T);
}

// Usage when processing API response
const backups = response.data.data.map((backup: Record<string, unknown>) => ({
  filename: unwrapValue(backup.filename),
  size_bytes: unwrapValue(backup.size_bytes),
  created_at: unwrapValue(backup.created_at),
}));
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Options API | Composition API with `<script setup>` | Vue 3 | Cleaner code, better TypeScript |
| Bootstrap-Vue | Bootstrap-Vue-Next | Vue 3 migration | Updated component names (BTable, BModal) |
| Mixins | Composables | Vue 3 | Better reusability, explicit dependencies |
| confirm() dialogs | BModal with typed confirmation | UX best practices | Better user experience, accessibility |

**Deprecated/outdated:**
- Options API for new components: Use `<script setup lang="ts">` instead
- Custom polling: Use useAsyncJob composable
- Mixins: Convert to composables for new code

## Open Questions

Things that couldn't be fully resolved:

1. **Download Endpoint Location**
   - What we know: Phase 49 created list/create/restore endpoints
   - What's unclear: Download endpoint not explicitly documented; may need to be added
   - Recommendation: Check if `/api/backup/download/:filename` exists; if not, add to Phase 49 or create as part of UI phase

2. **Post-Restore Behavior**
   - What we know: CONTEXT.md leaves this to Claude's discretion
   - What's unclear: Whether to show message, suggest logout, or force reload
   - Recommendation: Show success toast with message "Database restored. You may need to log out and log back in for changes to take effect." - non-disruptive but informative

3. **Status Location**
   - What we know: CONTEXT.md leaves status feedback location to Claude's discretion
   - What's unclear: Inline below button vs toast vs dedicated status area
   - Recommendation: Follow ManageAnnotations.vue pattern - inline progress below action button with animated progress bar

## Sources

### Primary (HIGH confidence)
- Existing codebase: `app/src/views/admin/ManageAnnotations.vue` - async job pattern with progress
- Existing codebase: `app/src/views/admin/ManageUser.vue` - modal with typed confirmation (DELETE)
- Existing codebase: `app/src/composables/useAsyncJob.ts` - job polling composable
- Existing codebase: `api/endpoints/backup_endpoints.R` - API endpoints available
- Existing codebase: `app/src/router/routes.ts` - admin route patterns

### Secondary (MEDIUM confidence)
- [UX Movement - Type to Confirm Pattern](https://uxmovement.com/buttons/how-to-make-sure-users-dont-accidentally-delete/) - type-to-confirm UX rationale
- [NN/G Confirmation Dialogs](https://www.nngroup.com/articles/confirmation-dialog/) - when to use confirmation dialogs
- [Cloudscape Delete Pattern](https://cloudscape.design/patterns/resource-management/delete/delete-with-additional-confirmation/) - type resource name pattern
- [Vue.js Feed - Axios Download](https://vuejsfeed.com/blog/tutorial-download-file-with-vue-js-and-axios) - blob download pattern

### Tertiary (LOW confidence)
- Web search for admin dashboard UX trends - general patterns, not Vue-specific

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all components already in codebase
- Architecture: HIGH - patterns directly from existing admin views
- Pitfalls: HIGH - based on existing code patterns and common Vue/JS issues
- Code examples: HIGH - adapted from existing codebase patterns

**Research date:** 2026-01-29
**Valid until:** 90 days (stable infrastructure, Vue 3 patterns established)
