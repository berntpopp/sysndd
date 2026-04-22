# Phase 33: Logging & Analytics - Context

**Gathered:** 2026-01-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Add advanced filtering and export to ViewLogs with feature parity to TablesEntities (search, pagination, URL sync). Admin can filter logs by user/action type, export to CSV for compliance, and view full JSON payload in detail modal.

</domain>

<decisions>
## Implementation Decisions

### Filter UX
- **User filter**: Dropdown with typeahead autocomplete (matches ManageUser pattern), loads users asynchronously from API
- **Action type filter**: Multi-select checkboxes for CREATE/UPDATE/DELETE/READ operations (Bootstrap-Vue-Next BFormSelect with multiple)
- **Active filter display**: Show applied filters as removable badges (pills) above table — same pattern as ManageUser.vue activeFilters
- **Clear all**: Single "Clear all" link next to filter badges
- **Date range**: Optional date picker for time-bounded queries (pre-set options: Today, Last 7 days, Last 30 days, Custom)
- **Filter persistence**: URL state sync via history.replaceState (not router.replace) — bookmarkable filtered views

### Log Detail View
- **Display pattern**: Right-side drawer/modal (keeps table context visible while reviewing details)
- **JSON formatting**: Syntax-highlighted, collapsible JSON with expand/collapse controls
- **Copy to clipboard**: Single-click copy button for full JSON payload
- **Navigation**: Keyboard arrows (←/→) to step through log entries while drawer stays open
- **Fields shown**: Full audit trail — timestamp, user, action, resource, status, request/response payload, duration, source IP

### CSV Export
- **Column selection**: Export visible columns by default; no custom column picker needed (keep simple)
- **Date range**: Export respects current filter state (filtered export, not full dump)
- **Filename convention**: `sysndd_audit_logs_YYYY-MM-DD.csv`
- **Size limit**: Warn if export exceeds 30,000 entries (industry standard limit for performance)
- **Server-side**: Use existing API `format=xlsx` parameter — already implemented in TablesLogs

### Table Presentation
- **Default visible columns**: timestamp, user, action, resource, status, duration (hide verbose fields like full query/post)
- **Timestamp format**: Relative time with tooltip showing absolute (e.g., "2 hours ago" → hover shows "2026-01-25 14:32:15 UTC")
- **Status badges**: Color-coded — green (200 OK), yellow (4xx client error), red (5xx server error)
- **Method badges**: Color-coded per HTTP verb (GET=blue, POST=green, PUT=yellow, DELETE=red) — matches existing TablesLogs pattern
- **Truncation**: Long values (query, post) truncated to 50 chars with "..." and full content in detail modal
- **Row hover**: Subtle highlight + cursor pointer indicating clickable for details
- **Empty state**: Icon + "No logs match your filters" with "Clear filters" action button

### Module-Level Caching
- Adopt TablesEntities module-level caching pattern (moduleLastApiParams, moduleApiCallInProgress) to prevent duplicate API calls on component remount
- Use initialization guard (isInitializing flag) to prevent watchers from triggering during mounted() setup

### Claude's Discretion
- Exact drawer width and animation timing
- Specific JSON syntax highlighting library (vue-json-pretty or similar)
- Toast messages for copy-to-clipboard success
- Loading skeleton vs spinner choice during initial load
- Exact spacing and typography within drawer

</decisions>

<specifics>
## Specific Ideas

- "Right-side drawer keeps you in context while reviewing" — industry best practice from HighLevel's audit log redesign
- Keyboard navigation (←/→) while drawer is open speeds up security incident investigation
- Filter pills pattern already exists in ManageUser.vue — reuse activeFilters computed + BBadge display
- Relative timestamps with absolute tooltip reduces cognitive load while preserving precision when needed
- Status/method color badges already exist in TablesLogs — extend pattern, don't reinvent

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 33-logging-analytics*
*Context gathered: 2026-01-25*

## References

Best practices sourced from:
- [UI Bakery Audit Logs](https://docs.uibakery.io/concepts/workspace-management/audit-logs)
- [Permit.io Authorization Audit Logs](https://www.permit.io/blog/audit-logs)
- [HighLevel Audit Logs New Design](https://help.gohighlevel.com/support/solutions/articles/155000006667-audit-logs-introducing-the-new-design-experience)
- [GitHub Enterprise Audit Log Export](https://docs.github.com/en/enterprise-cloud@latest/admin/monitoring-activity-in-your-enterprise/reviewing-audit-logs-for-your-enterprise/exporting-audit-log-activity-for-your-enterprise)
- [Azure DevOps Audit Filtering](https://learn.microsoft.com/en-us/azure/devops/organizations/audit/azure-devops-auditing)
