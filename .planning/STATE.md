# State: SysNDD Developer Experience

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-25)

**Core value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

**Current focus:** v6.0 Admin Panel Modernization — Phase 31 (Content Management) COMPLETE

## Current Position

**Milestone:** v6.0 Admin Panel Modernization
**Phase:** 31 of 33 (Content Management) COMPLETE
**Plan:** 04 of 04 complete
**Status:** Phase complete
**Last activity:** 2026-01-26 — Completed 31-04-PLAN.md (ManageAbout Integration)

```
v6.0 Admin Panel Modernization: [████████████████░░░░░░░░░░░░] 52%
Phase 28 Table Foundation:     [██████████] 3/3 plans ✓
Phase 29 User Management:      [██████████] 4/4 plans ✓
Phase 30 Statistics Dashboard: [██████████] 3/3 plans ✓
Phase 31 Content Management:   [██████████] 4/4 plans ✓
```

## Performance Metrics

**Velocity (across all milestones):**
- Total plans completed: 145
- Milestones shipped: 5 (v1-v5)
- Phases completed: 28

**By Milestone:**

| Milestone | Phases | Plans | Shipped |
|-----------|--------|-------|---------|
| v1 Developer Experience | 1-5 | 19 | 2026-01-21 |
| v2 Docker Infrastructure | 6-9 | 8 | 2026-01-22 |
| v3 Frontend Modernization | 10-17 | 53 | 2026-01-23 |
| v4 Backend Overhaul | 18-24 | 42 | 2026-01-24 |
| v5 Analysis Modernization | 25-27 | 16 | 2026-01-25 |

**v6.0 Progress:**
- Plans completed: 14
- Phases completed: 4 (Phases 28-31)
- Average duration: 2.9min
- Trend: Strong velocity

*Updated after each plan completion*

## Accumulated Context

### Decisions

See PROJECT.md for full decisions table.

Recent v6-relevant decisions:
- **TablesEntities pattern**: URL state sync via VueUse useUrlSearchParams, module-level caching
- **ManageAnnotations pattern**: Proper async job cleanup in beforeUnmount, elapsed time display
- **Bootstrap-Vue-Next 0.42.0**: Has all needed components (BTable, BCard, BModal, BForm)
- **Chart.js + vue-chartjs**: Chosen for v6 statistics dashboard (~50KB gzipped)
- **TipTap**: Chosen for v6 CMS editor (~80KB gzipped, TypeScript-native)
- **Table endpoint pattern** (28-01): filter, sort, page_after, page_size, fspec params; { links, meta, data } response
- **Field specification metadata** (28-01): fspec in meta enables frontend dynamic table column generation
- **Module-level API caching** (28-02): Prevents duplicate API calls on component remount using moduleLastApiParams, moduleApiCallInProgress
- **URL state sync** (28-02): history.replaceState (not router.replace) avoids component remount during URL updates
- **Initialization guard** (28-02): isInitializing flag prevents watchers from triggering during mounted() setup
- **Bulk 20-user limit** (29-01): Enforce 20 user maximum per bulk request to prevent timeouts
- **Admin deletion protection** (29-01): Reject bulk delete if any user is Administrator (prevents accidental admin deletion)
- **Atomic transaction semantics** (29-01): Use all-or-nothing transactions for bulk operations (data consistency)
- **Set-based selection** (29-02): Reactive Set (not array) for O(1) lookups, always create new Set for Vue reactivity
- **VueUse useLocalStorage** (29-02): Reactive localStorage binding for filter presets with custom serializer
- **Deep copy on filter save/load** (29-02): JSON.parse(JSON.stringify()) prevents mutation bugs
- **Selection limit returns false** (29-02): toggleSelection returns boolean (not throw) for non-blocking UX
- **Bootstrap modal confirmation pattern** (29-04): All bulk actions use Bootstrap modals with username lists (not native confirm/prompt)
- **Type-to-confirm for destructive actions** (29-04): Bulk delete requires exact "DELETE" text input to enable confirmation button
- **Dropdown for role selection** (29-04): Use BFormSelect dropdown instead of prompt() for better UX and validation
- **Frontend admin protection** (29-04): Block bulk delete if admins in selection before showing modal (fail fast)
- **Default filter presets** (29-04): Initialize "Pending" and "Curators" presets on first mount for common workflows
- **Tree-shaken Chart.js registration** (30-01): Manual component registration reduces bundle size ~30-40% vs registerables
- **Trend delta comparison** (30-03): Compare equal-length periods for trend calculation (not calendar periods)
- **Admin dashboard layout** (30-03): KPI cards row at top, then charts, then detail cards
- **JSON column for sections** (31-01): Use JSON storage for flexible CMS section schema (no migrations for structure changes)
- **Single draft per user** (31-01): Upsert pattern (DELETE + INSERT) enforces one active draft per user
- **Version auto-increment** (31-01): MAX(version) + 1 query for explicit version numbers in published content
- **Public CMS endpoint** (31-01): GET /published requires no auth for About.vue consumption
- **Global vue-dompurify-html** (31-03): Registered VueDOMPurifyHTML plugin in main.ts for consistent XSS sanitization
- **Side-by-side editor/preview** (31-03): Editor left, preview right at SectionEditor level (not page level)
- **Drag handle pattern** (31-03): .drag-handle class with grab/grabbing cursors for vuedraggable integration
- **Auto-expand new sections** (31-03): New sections added via "Add Section" auto-expand for immediate editing

### Pending Todos

None yet.

### Blockers/Concerns

**v6.0 planning:**
- Need to verify mirai job cancellation support during Phase 32 planning
- Bundle size: Phase 31-02 added ~130KB (markdown-it ~80KB, dompurify ~45KB, vuedraggable ~5KB)
- Bulk operation audit logging not yet implemented (planned for Phase 32)
- Need to verify markdown rendering performance with large content (>10KB markdown)

## Session Continuity

**Last session:** 2026-01-26 00:20 UTC
**Stopped at:** Completed Phase 31 (Content Management)
**Resume file:** None
**Next action:** Start Phase 32 (Async Jobs)

---
*State initialized: 2026-01-20*
*Last updated: 2026-01-26 — Completed Phase 31 (Content Management)*
