# Phase 33: Logging & Analytics - Research

**Researched:** 2026-01-25
**Domain:** Vue 3 admin interface for audit log filtering, CSV export, and detailed log viewing
**Confidence:** HIGH

## Summary

This phase extends ViewLogs with advanced filtering capabilities (user, action type, date range), CSV export for compliance, and a detail drawer for viewing full log JSON payloads. The implementation follows established patterns from TablesEntities and ManageUser for filter/pagination/URL sync consistency.

**Key findings:**
- Existing codebase already implements module-level caching pattern (TablesEntities, ManageUser) to prevent duplicate API calls on component remount
- API endpoint `/api/logs` supports filtering, sorting, pagination, and XLSX export via `format=xlsx` parameter
- Bootstrap-Vue-Next 0.42 provides BOffcanvas component for right-side drawer implementation
- URL state management via `history.replaceState` (not `router.replace`) prevents component remount issues
- Filter pills pattern already exists in ManageUser.vue with activeFilters computed property

**Primary recommendation:** Extend TablesLogs.vue using TablesEntities architecture patterns (module-level caching, initialization guards, updateBrowserUrl method). Use Bootstrap-Vue-Next BOffcanvas for detail drawer. Leverage VueUse useDateFormat or native Intl.RelativeTimeFormat for relative timestamps.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.5.25 | Frontend framework | Already adopted, Composition API for state management |
| Bootstrap-Vue-Next | 0.42.0 | UI component library | Project standard, provides BOffcanvas for drawer, BFormSelect for filters |
| VueUse | 14.1.0 | Vue composables | Already in package.json, provides useDateFormat for timestamps |
| axios | 1.13.2 (dev) | HTTP client | Already configured with auth headers, used in all table components |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| xlsx | 0.18.5 | Excel/CSV export | Already used in TablesLogs requestExcel method, supports CSV via SheetJS |
| @vueuse/core | 14.1.0 | Composables (clipboard, storage) | For copy-to-clipboard functionality in log detail drawer |
| date-fns | (optional) | Date formatting utilities | If VueUse useDateFormat insufficient for relative time formatting |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Bootstrap BOffcanvas | Custom CSS drawer | BOffcanvas is native Bootstrap 5, accessible, no custom implementation needed |
| VueUse useDateFormat | date-fns/dayjs | VueUse already in project, simpler for basic formatting. dayjs adds 7KB, date-fns 13KB |
| xlsx library | Client-side CSV generation | xlsx already in package.json, handles edge cases (quotes, commas) |

**Installation:**
```bash
# All dependencies already present in package.json
# No new packages required
```

## Architecture Patterns

### Recommended Project Structure
```
app/src/
├── views/admin/
│   └── ViewLogs.vue              # Container view (minimal changes)
├── components/tables/
│   └── TablesLogs.vue            # Main table component (major updates)
├── components/small/
│   ├── LogDetailDrawer.vue       # NEW: Right-side drawer for log details
│   └── LogFilterBadges.vue       # NEW: Active filter pills display
└── composables/
    ├── useTableData.ts           # Already exists, no changes
    ├── useTableMethods.ts        # Already exists, no changes
    └── useLogFormatting.ts       # NEW: Log-specific formatting (status badges, relative time)
```

### Pattern 1: Module-Level Caching to Prevent Duplicate API Calls
**What:** Module-scoped variables track last API parameters and response, surviving component remounts caused by URL updates
**When to use:** Table components with URL state sync to prevent duplicate calls when `history.replaceState` causes router navigation
**Example:**
```typescript
// Source: TablesEntities.vue lines 266-271
let moduleLastApiParams = null;
let moduleApiCallInProgress = false;
let moduleLastApiCallTime = 0;
let moduleLastApiResponse = null;

// In doLoadData():
if (moduleLastApiParams === urlParam && (now - moduleLastApiCallTime) < 500) {
  if (moduleLastApiResponse) {
    this.applyApiResponse(moduleLastApiResponse);
    this.isBusy = false;
  }
  return;
}
```

### Pattern 2: Initialization Guard to Prevent Watcher Triggering During Setup
**What:** `isInitializing` flag prevents watch handlers from firing during mounted() lifecycle, avoiding duplicate API calls
**When to use:** Components with deep watchers on filter/sortBy objects that trigger API calls
**Example:**
```typescript
// Source: TablesEntities.vue lines 358-448
data() {
  return {
    isInitializing: true,
    // ...
  };
},
watch: {
  filter: {
    handler() {
      if (this.isInitializing) return; // Skip during mount
      this.filtered();
    },
    deep: true,
  },
},
mounted() {
  // ... setup filter/sort
  this.loadData();
  this.$nextTick(() => {
    this.isInitializing = false; // Enable watchers AFTER initial load
  });
}
```

### Pattern 3: URL State Sync via history.replaceState (Not router.replace)
**What:** Update browser URL after successful API response using native History API to avoid component remount
**When to use:** Table components that need bookmarkable filtered states without triggering Vue Router navigation
**Example:**
```typescript
// Source: TablesEntities.vue lines 491-514
updateBrowserUrl() {
  if (this.isInitializing) return;
  const searchParams = new URLSearchParams();
  if (this.sort) searchParams.set('sort', this.sort);
  if (this.filter_string) searchParams.set('filter', this.filter_string);
  if (this.currentItemID > 0) searchParams.set('page_after', String(this.currentItemID));
  searchParams.set('page_size', String(this.perPage));

  // Use history.replaceState to update URL WITHOUT triggering Vue Router navigation
  const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
  window.history.replaceState({ ...window.history.state }, '', newUrl);
}
```
**Why history.replaceState over router.replace:** Vue Router's `router.replace()` can trigger component remount even when the component is the same, causing duplicate API calls. `history.replaceState` updates the URL without Vue Router navigation, preserving component instance and module-level cache. See [Vue Router Issue #3595](https://github.com/vuejs/vue-router/issues/3595).

### Pattern 4: Filter Pills with Clear Actions
**What:** Display active filters as dismissible badges above table with individual and bulk clear actions
**When to use:** Admin interfaces with multiple filter controls to provide visibility and quick removal
**Example:**
```vue
<!-- Source: ManageUser.vue lines 192-219 -->
<BRow v-if="hasActiveFilters" class="px-2 pb-2">
  <BCol>
    <BBadge
      v-for="(activeFilter, index) in activeFilters"
      :key="index"
      variant="secondary"
      class="me-2 mb-1"
    >
      {{ activeFilter.label }}: {{ activeFilter.value }}
      <BButton
        size="sm"
        variant="link"
        class="p-0 ms-1 text-light"
        @click="clearFilter(activeFilter.key)"
      >
        <i class="bi bi-x" />
      </BButton>
    </BBadge>
    <BButton size="sm" variant="link" class="p-0" @click="removeFilters">
      Clear all
    </BButton>
  </BCol>
</BRow>

<script>
computed: {
  hasActiveFilters() {
    return Object.values(this.filter).some(f => f.content !== null && f.content !== '');
  },
  activeFilters() {
    const filters = [];
    if (this.filter.any.content) filters.push({ key: 'any', label: 'Search', value: this.filter.any.content });
    if (this.filter.user_role.content) filters.push({ key: 'user_role', label: 'Role', value: this.filter.user_role.content });
    return filters;
  },
}
</script>
```

### Pattern 5: Bootstrap Offcanvas for Detail Drawer
**What:** Bootstrap 5 native offcanvas component for right-side drawer that slides over content
**When to use:** Detail views that should remain accessible while preserving table context (audit logs, notifications, activity feeds)
**Example:**
```vue
<!-- Bootstrap-Vue-Next BOffcanvas usage -->
<BOffcanvas v-model="showLogDetail" placement="end" title="Log Details">
  <template #header>
    <h5>Log Entry #{{ selectedLog?.id }}</h5>
    <BButton variant="link" @click="showLogDetail = false">
      <i class="bi bi-x-lg" />
    </BButton>
  </template>

  <!-- Drawer body content -->
  <div class="log-detail-content">
    <pre>{{ JSON.stringify(selectedLog, null, 2) }}</pre>
  </div>
</BOffcanvas>
```
**Sources:**
- [Bootstrap 5 Offcanvas Documentation](https://getbootstrap.com/docs/5.3/components/offcanvas/)
- [Bootstrap-Vue-Next Offcanvas Component](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/offcanvas.html)

### Pattern 6: Relative Timestamps with Absolute Tooltip
**What:** Display human-readable relative time ("2 hours ago") with hover tooltip showing precise timestamp
**When to use:** Audit logs, activity feeds, timestamps where recency matters more than precision
**Example:**
```vue
<template>
  <div
    v-b-tooltip.hover.top
    :title="formatAbsolute(row.timestamp)"
  >
    {{ formatRelative(row.timestamp) }}
  </div>
</template>

<script>
methods: {
  formatRelative(dateStr) {
    // Using Intl.RelativeTimeFormat (native browser API, no library needed)
    const now = new Date();
    const date = new Date(dateStr);
    const diffMs = date - now;
    const diffMins = Math.round(diffMs / 60000);
    const diffHours = Math.round(diffMs / 3600000);
    const diffDays = Math.round(diffMs / 86400000);

    const rtf = new Intl.RelativeTimeFormat('en', { numeric: 'auto' });
    if (Math.abs(diffMins) < 60) return rtf.format(diffMins, 'minute');
    if (Math.abs(diffHours) < 24) return rtf.format(diffHours, 'hour');
    return rtf.format(diffDays, 'day');
  },
  formatAbsolute(dateStr) {
    return new Date(dateStr).toLocaleString('en-US', {
      year: 'numeric', month: 'short', day: 'numeric',
      hour: '2-digit', minute: '2-digit', timeZoneName: 'short'
    });
  }
}
</script>
```
**Alternative with VueUse:**
```typescript
import { useDateFormat } from '@vueuse/core';

// In setup():
const formatted = useDateFormat(timestamp, 'YYYY-MM-DD HH:mm:ss');
```

### Pattern 7: CSV Export Respecting Filter State
**What:** Export button triggers server-side CSV generation with current filter parameters applied
**When to use:** Compliance reporting where exported data must match visible filtered data
**Example:**
```typescript
// Source: TablesLogs.vue lines 486-514
async requestExcel() {
  this.downloading = true;
  try {
    const response = await this.axios.get(`${import.meta.env.VITE_API_URL}/api/logs`, {
      params: {
        page_after: 0,
        page_size: 'all', // Export all filtered results
        format: 'xlsx', // API returns binary XLSX file
        filter: this.filter_string, // Apply current filters
        sort: this.sort,
      },
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    });

    const fileURL = window.URL.createObjectURL(new Blob([response.data]));
    const fileLink = document.createElement('a');
    fileLink.href = fileURL;
    fileLink.setAttribute('download', 'logs_table.xlsx');
    document.body.appendChild(fileLink);
    fileLink.click();
  } catch (e) {
    this.makeToast(e, 'Error', 'danger');
  }
  this.downloading = false;
}
```

### Anti-Patterns to Avoid
- **Using router.replace for URL updates:** Triggers component remount, defeats module-level cache. Use history.replaceState instead.
- **Watchers without initialization guards:** Causes duplicate API calls during mounted() when filters are initialized from URL params.
- **Client-side CSV generation for large datasets:** Edge cases with special characters, memory issues. Server-side generation via API is more robust.
- **Parsing URLs with string manipulation:** Use URLSearchParams for type safety and proper encoding.
- **Global state for drawer visibility:** Component-level reactive ref is sufficient and avoids unintended side effects.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Right-side drawer animation | Custom CSS transitions + z-index management | Bootstrap BOffcanvas component | Accessibility (focus trapping, ARIA), keyboard support (Esc to close), backdrop handling, mobile-responsive, already styled |
| CSV export with special characters | String concatenation with quote escaping | xlsx library (already in package.json) | Handles edge cases: quotes in values, commas, newlines, Unicode, Excel compatibility |
| Relative time formatting | Custom time-ago calculator | Intl.RelativeTimeFormat (native) or VueUse useDateFormat | i18n support, automatic pluralization, browser-native (no bundle size), handles past/future |
| URL state sync | Manual window.location manipulation | URLSearchParams + history.replaceState | Type-safe parameter handling, proper encoding, maintains router state |
| Date range picker | Custom calendar component | Bootstrap-Vue-Next date picker (if available) or native input type="date" | Accessibility, mobile support, localization, keyboard navigation |
| Keyboard navigation in drawer | Custom keydown handlers | Browser focus management + tabindex | Screen reader compatibility, platform-consistent behavior |

**Key insight:** Admin audit log interfaces have well-established UX patterns. Don't reinvent drawer mechanics, CSV export, or timestamp formatting—these are solved problems with mature libraries. Focus implementation effort on domain-specific logic (filter combinations, log field mappings, compliance requirements).

## Common Pitfalls

### Pitfall 1: Component Remount on URL Update Causing Duplicate API Calls
**What goes wrong:** Using `router.replace()` to update URL with filter state causes component to remount, triggering mounted() lifecycle again. Module-level cache is preserved but watchers fire, causing duplicate API calls.
**Why it happens:** Vue Router navigation (even replace) can trigger component recreation if route params/query change significantly. The router doesn't distinguish "state update" from "navigation."
**How to avoid:**
1. Use `history.replaceState` instead of `router.replace` for URL updates
2. Call `updateBrowserUrl()` AFTER successful API response, not before
3. Implement initialization guard (`isInitializing` flag) to prevent watchers from firing during mounted()
**Warning signs:** Network tab shows duplicate requests for same parameters. Console logs mounted() lifecycle firing twice.

### Pitfall 2: Filter Watchers Triggering During Initialization
**What goes wrong:** Setting filter values in mounted() from URL params triggers deep watchers, calling filtered() before initial loadData() completes. Results in two API calls: one from explicit loadData(), one from watcher.
**Why it happens:** Vue 3's deep watch on objects fires immediately when nested properties change, even during initialization.
**How to avoid:**
```typescript
data() {
  return { isInitializing: true };
},
watch: {
  filter: {
    handler() {
      if (this.isInitializing) return; // Guard clause
      this.filtered();
    },
    deep: true,
  },
},
mounted() {
  // Parse URL params and set filter
  if (urlParams.get('filter')) {
    this.filter = this.filterStrToObj(urlParams.get('filter'), this.filter);
  }
  this.loadData(); // Explicit initial load
  this.$nextTick(() => {
    this.isInitializing = false; // Enable watchers AFTER initial load
  });
}
```
**Warning signs:** Network tab shows 2 API calls with same parameters within milliseconds.

### Pitfall 3: Date Range Filter Without User Timezone Handling
**What goes wrong:** Server stores timestamps in UTC, user filters by date range assuming local timezone. Query returns unexpected results (e.g., "Today" includes yesterday's logs).
**Why it happens:** Date pickers return local dates (e.g., "2026-01-25"), but server interprets as UTC midnight. For users in GMT+8, local midnight is 16:00 previous day UTC.
**How to avoid:**
1. Convert local date selections to UTC before sending to API
2. Display "Last 24 hours" instead of "Today" for relative filters
3. Document timezone behavior in UI (e.g., "All times shown in UTC")
**Warning signs:** User reports missing logs when filtering by current day. Logs appear in wrong day when timezone offset crosses midnight.

### Pitfall 4: Large CSV Exports Blocking Browser UI
**What goes wrong:** Fetching 100K+ log entries as CSV causes browser tab to freeze while generating file, appears unresponsive.
**Why it happens:** Synchronous blob creation and download link manipulation blocks main thread.
**How to avoid:**
1. Show loading indicator with download in progress state
2. Implement server-side pagination for very large exports (>30K rows)
3. Warn user before exporting large datasets: "This export contains 45,000 rows and may take a minute"
4. Use streaming download if possible (Content-Disposition: attachment)
**Warning signs:** Browser shows "Page Unresponsive" warning during export. UI freezes with no feedback.

### Pitfall 5: Drawer Content Not Keyboard Accessible
**What goes wrong:** Drawer opens but focus remains on table, keyboard users can't navigate drawer content. Tab cycles through background elements instead of drawer.
**Why it happens:** No focus management when drawer opens. Bootstrap's BOffcanvas handles this, but custom implementations often miss it.
**How to avoid:**
1. Use Bootstrap-Vue-Next BOffcanvas component (handles focus automatically)
2. If custom drawer, set `autofocus` on first focusable element
3. Trap focus within drawer while open (prevent Tab from escaping)
4. Return focus to trigger button when drawer closes
**Warning signs:** Pressing Tab after opening drawer focuses background elements. Screen reader announces wrong elements.

### Pitfall 6: JSON Payload Display Without Sanitization
**What goes wrong:** Displaying raw log JSON in drawer can expose sensitive data (passwords, tokens) or cause XSS if log contains malicious HTML.
**Why it happens:** Logs might contain user input that was logged verbatim. Using v-html without sanitization is dangerous.
**How to avoid:**
1. Use `<pre>{{ JSON.stringify(data, null, 2) }}</pre>` (text interpolation, not v-html)
2. Implement server-side redaction of sensitive fields before returning logs
3. Use syntax highlighting libraries that escape HTML (e.g., highlight.js)
**Warning signs:** JSON viewer renders HTML tags as elements. Security audit flags XSS vulnerability.

## Code Examples

Verified patterns from existing codebase:

### Module-Level Caching Pattern
```typescript
// Source: TablesEntities.vue lines 266-271, 583-634
// Module-level variables survive component remount
let moduleLastApiParams = null;
let moduleApiCallInProgress = false;
let moduleLastApiCallTime = 0;
let moduleLastApiResponse = null;

export default {
  // ...
  methods: {
    async doLoadData() {
      const urlParam = `sort=${this.sort}&filter=${this.filter_string}&page_after=${this.currentItemID}&page_size=${this.perPage}`;
      const now = Date.now();

      // Prevent duplicate calls using module-level tracking
      if (moduleLastApiParams === urlParam && (now - moduleLastApiCallTime) < 500) {
        if (moduleLastApiResponse) {
          this.applyApiResponse(moduleLastApiResponse);
          this.isBusy = false;
        }
        return;
      }

      if (moduleApiCallInProgress && moduleLastApiParams === urlParam) return;

      moduleLastApiParams = urlParam;
      moduleLastApiCallTime = now;
      moduleApiCallInProgress = true;
      this.isBusy = true;

      try {
        const response = await this.axios.get(apiUrl);
        moduleApiCallInProgress = false;
        moduleLastApiResponse = response.data; // Cache for remounted components
        this.applyApiResponse(response.data);
        this.updateBrowserUrl(); // Update URL AFTER success
        this.isBusy = false;
      } catch (e) {
        moduleApiCallInProgress = false;
        this.makeToast(e, 'Error', 'danger');
        this.isBusy = false;
      }
    },
  },
};
```

### Active Filter Pills Display
```vue
<!-- Source: ManageUser.vue lines 192-219 -->
<template>
  <BRow v-if="hasActiveFilters" class="px-2 pb-2">
    <BCol>
      <BBadge
        v-for="(activeFilter, index) in activeFilters"
        :key="index"
        variant="secondary"
        class="me-2 mb-1"
      >
        {{ activeFilter.label }}: {{ activeFilter.value }}
        <BButton
          size="sm"
          variant="link"
          class="p-0 ms-1 text-light"
          @click="clearFilter(activeFilter.key)"
        >
          <i class="bi bi-x" />
        </BButton>
      </BBadge>
      <BButton size="sm" variant="link" class="p-0" @click="removeFilters">
        Clear all
      </BButton>
    </BCol>
  </BRow>
</template>

<script>
computed: {
  hasActiveFilters() {
    return Object.values(this.filter).some(f => f.content !== null && f.content !== '');
  },
  activeFilters() {
    const filters = [];
    if (this.filter.any.content) {
      filters.push({ key: 'any', label: 'Search', value: this.filter.any.content });
    }
    if (this.filter.user_role.content) {
      filters.push({ key: 'user_role', label: 'Role', value: this.filter.user_role.content });
    }
    if (this.filter.approved.content !== null) {
      filters.push({
        key: 'approved',
        label: 'Status',
        value: this.filter.approved.content === '1' ? 'Approved' : 'Pending'
      });
    }
    return filters;
  },
},
methods: {
  clearFilter(key) {
    if (this.filter[key]) {
      this.filter[key].content = null;
    }
    this.filtered();
  },
}
</script>
```

### Status Badge Color Mapping
```typescript
// Source: TablesLogs.vue lines 524-533
getMethodVariant(method) {
  const methodVariants = {
    GET: 'success',      // Green
    POST: 'primary',     // Blue
    PUT: 'warning',      // Yellow
    DELETE: 'danger',    // Red
    OPTIONS: 'info',     // Light blue
  };
  return methodVariants[method] || 'secondary';
}

// Apply in template:
<BBadge :variant="getMethodVariant(row.request_method)">
  {{ row.request_method }}
</BBadge>
```

### Copy to Clipboard with VueUse
```typescript
// Using VueUse useClipboard composable
import { useClipboard } from '@vueuse/core';

export default {
  setup() {
    const { copy, copied } = useClipboard();

    const copyJsonToClipboard = (logData) => {
      const jsonString = JSON.stringify(logData, null, 2);
      copy(jsonString);
    };

    return { copyJsonToClipboard, copied };
  },
};

// In template:
<BButton @click="copyJsonToClipboard(selectedLog)">
  <i class="bi" :class="copied ? 'bi-check' : 'bi-clipboard'" />
  {{ copied ? 'Copied!' : 'Copy JSON' }}
</BButton>
```

### Keyboard Navigation in Drawer
```vue
<template>
  <BOffcanvas
    v-model="showLogDetail"
    placement="end"
    @shown="handleDrawerShown"
    @keydown="handleKeydown"
  >
    <!-- Drawer content -->
  </BOffcanvas>
</template>

<script>
export default {
  data() {
    return {
      currentLogIndex: 0,
      logs: [], // All logs on current page
    };
  },
  methods: {
    handleDrawerShown() {
      // Focus first interactive element when drawer opens
      this.$nextTick(() => {
        this.$el.querySelector('button')?.focus();
      });
    },
    handleKeydown(event) {
      if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') {
        event.preventDefault();
        this.navigateToPreviousLog();
      } else if (event.key === 'ArrowRight' || event.key === 'ArrowDown') {
        event.preventDefault();
        this.navigateToNextLog();
      } else if (event.key === 'Escape') {
        this.showLogDetail = false; // BOffcanvas handles this by default
      }
    },
    navigateToPreviousLog() {
      if (this.currentLogIndex > 0) {
        this.currentLogIndex--;
        this.selectedLog = this.logs[this.currentLogIndex];
      }
    },
    navigateToNextLog() {
      if (this.currentLogIndex < this.logs.length - 1) {
        this.currentLogIndex++;
        this.selectedLog = this.logs[this.currentLogIndex];
      }
    },
  },
};
</script>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| router.replace() for URL updates | history.replaceState() | ~2023 (Vue Router 4 issues) | Prevents component remount, enables module-level caching |
| Moment.js for date formatting | Intl.RelativeTimeFormat (native) or date-fns | ~2024 | Smaller bundle (moment.js 67KB → 0KB native or 13KB date-fns) |
| Custom drawer components | Bootstrap 5 Offcanvas | 2021 (Bootstrap 5.0) | Accessibility built-in, mobile-responsive, less custom code |
| Client-side CSV export | Server-side generation via API | N/A (always preferred) | Handles large datasets, prevents browser freeze |
| Treeselect for multi-select | BFormSelect with multiple | 2024 (Bootstrap-Vue-Next migration) | Simpler API, better Bootstrap integration, pending full multi-select |

**Deprecated/outdated:**
- **Moment.js:** Deprecated in favor of native Intl API or date-fns/dayjs (smaller, modern). Last major update 2020.
- **vue-treeselect:** Original library for Vue 2. Bootstrap-Vue-Next components preferred for consistency (note: TablesEntities comments indicate treeselect disabled pending migration).
- **Custom modal implementations:** Bootstrap 5 Modal/Offcanvas components provide accessible, mobile-friendly alternatives to custom implementations.

## Open Questions

Things that couldn't be fully resolved:

1. **Date Range Picker Component Availability**
   - What we know: Bootstrap-Vue-Next 0.42 includes date picker in component list. Original BootstrapVue had `<b-form-datepicker>`.
   - What's unclear: Full API documentation for Bootstrap-Vue-Next date picker component. GitHub issue from April 2024 suggested it was still being requested.
   - Recommendation: Test Bootstrap-Vue-Next `<BFormDatepicker>` component availability. If unavailable, use native HTML `<input type="date">` as fallback or implement preset buttons (Today, Last 7 days, Last 30 days) instead of custom picker.

2. **User Filter Dropdown Data Source**
   - What we know: Context specifies "dropdown with typeahead autocomplete, loads users asynchronously from API." ManageUser.vue has `loadUserList()` method fetching from `/api/user/list?roles=Curator,Reviewer`.
   - What's unclear: Should user filter load ALL users (including viewers) or only curators/reviewers? Does API support name/email search for typeahead?
   - Recommendation: Create `/api/user/list` endpoint (or use existing) that returns all users with optional search parameter. Filter client-side if list is small (<1000 users), server-side if larger.

3. **Server-Side Log Size Limit**
   - What we know: Context suggests 30,000 entry warning as "industry standard limit for performance."
   - What's unclear: Does API `/api/logs?format=xlsx&page_size=all` already paginate or limit exports? Is there a database query timeout?
   - Recommendation: Test export with large filter result sets. If API doesn't limit, add frontend warning when `totalRows > 30000` before triggering export. Consider server-side streaming if exports exceed 100K rows.

4. **JSON Syntax Highlighting Library Choice**
   - What we know: Multiple Vue 3 JSON viewer options exist (vue3-json-viewer, json-editor-vue). VueUse doesn't provide JSON syntax highlighting.
   - What's unclear: Which library is most lightweight and maintenance-friendly? Do we need full JSON editor features (collapsible nodes) or just syntax-highlighted display?
   - Recommendation: Start with plain `<pre>{{ JSON.stringify(log, null, 2) }}</pre>` (no library). If collapsible nodes required, add vue3-json-viewer (11KB gzipped). Avoid full editors (json-editor-vue) for read-only use case.

## Sources

### Primary (HIGH confidence)
- Existing codebase files:
  - `/home/bernt-popp/development/sysndd/app/src/components/tables/TablesEntities.vue` - Module-level caching pattern, initialization guards, URL sync
  - `/home/bernt-popp/development/sysndd/app/src/components/tables/TablesLogs.vue` - Current implementation, CSV export, method badges
  - `/home/bernt-popp/development/sysndd/app/src/views/admin/ManageUser.vue` - Active filter pills pattern, filter presets
  - `/home/bernt-popp/development/sysndd/api/endpoints/logging_endpoints.R` - API endpoint capabilities (format=xlsx parameter)
- `/home/bernt-popp/development/sysndd/app/package.json` - Verified library versions (Vue 3.5.25, Bootstrap-Vue-Next 0.42.0, VueUse 14.1.0, xlsx 0.18.5)
- [Bootstrap 5 Offcanvas Documentation](https://getbootstrap.com/docs/5.3/components/offcanvas/) - Official Bootstrap 5 offcanvas API
- [Bootstrap-Vue-Next Offcanvas Component](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/offcanvas.html) - Vue 3 integration for BOffcanvas
- [VueUse useDateFormat](https://vueuse.org/shared/usedateformat/) - Date formatting composable

### Secondary (MEDIUM confidence)
- [Vue Router Programmatic Navigation](https://router.vuejs.org/guide/essentials/navigation.html) - Verified router.replace vs history.replaceState behavior
- [Vue Router Issue #3595](https://github.com/vuejs/vue-router/issues/3595) - Documented issue with router.replace causing component remount
- [shadcn/vue Drawer Component](https://www.shadcn-vue.com/docs/components/drawer) - Alternative drawer implementation pattern
- [Permit.io Audit Log Filtering](https://docs.permit.io/how-to/use-audit-logs/types-and-filtering/) - Industry patterns for audit log filters (user, action, date range)

### Tertiary (LOW confidence - requires verification)
- [vue3-json-viewer on GitHub](https://github.com/jeevan-lal/vue3-json-viewer) - JSON viewer option, not tested with project
- [Bootstrap-Vue-Next npm page](https://www.npmjs.com/package/bootstrap-vue-next) - Version 0.42.0 includes "Date picker" in component list, but documentation incomplete
- [date-fns official site](https://date-fns.org/) - Alternative to VueUse for date formatting, not currently in package.json
- [Best Practices for Handling Large CSV Files - Dromo](https://dromo.io/blog/best-practices-handling-large-csv-files) - General CSV best practices, not Vue-specific

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries verified in package.json and existing codebase
- Architecture patterns: HIGH - Extracted directly from working code (TablesEntities, ManageUser)
- Pitfalls: HIGH - Based on documented codebase issues (module-level caching added to fix remount problems)
- Date picker availability: MEDIUM - Bootstrap-Vue-Next lists component but documentation incomplete
- JSON viewer choice: LOW - Multiple options, no clear best practice in Vue ecosystem

**Research date:** 2026-01-25
**Valid until:** 60 days (February 2026) - stable technologies, slow-moving ecosystem
