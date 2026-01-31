# Phase 55: Bug Fixes - Context

**Gathered:** 2026-01-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Resolve 8 major entity and curation bugs (BUG-01 through BUG-08) to restore expected behavior. This is a debugging and fix phase — no new features. Bugs relate to entity updates (EIF2AK2, GAP43, MEF2C), curation workflows (viewer profile, PMID deletion, entities over time), and review processes (disease renaming approval, re-reviewer identity).

</domain>

<decisions>
## Implementation Decisions

### Entity Bugs (EIF2AK2, GAP43, MEF2C)
- These are **database debugging issues**, not UI/UX preferences
- GAP43 bug (#115) is likely orphaned records or constraint violations — investigate specifically what happens with this gene at database level
- EIF2AK2 (#122) and MEF2C (#114) — debug what happens in database when these entities are updated
- Entities should appear in **normal sorted position** (not forced to top)
- New entities should appear **immediately via reactive update** (no page refresh required)
- **Claude's discretion:** Add diagnostics/logging if helpful for identifying similar issues in future

### PMID Preservation Logic
- **Always preserve existing PMIDs** — new PMIDs are added, existing PMIDs never removed automatically
- Explicit removal only — follow existing removal pattern in curation workflow
- **Research required:** Investigate current re-review UI/UX in detail (use Playwright), research best practices for PMID change feedback
- **Verify all workflows:** Check PMID handling across all curation workflows, not just re-review

### Approval Workflow for Disease Renaming
- Disease renaming currently bypasses approval (bug #41) — this needs to change
- Should follow **same flow as re-review** — appear in status/approval tables
- Use **existing approval roles and patterns** — match other approval workflows
- Use **existing notification patterns** — no special notification system
- **Research required:** Deeply investigate current disease renaming logic, compare with best practices via web search, help decide optimal approach

### Error Feedback & User Messaging
- **User-friendly toast with expandable technical details**
- Include **"copy error" button** for easy bug reporting
- This should be a **reusable pattern** (DRY, KISS, SOLID, modularization)
- Create error feedback component usable across codebase

### Entities Over Time Chart (Bug #44)
- **Thoroughly investigate** database, queries, and API
- Confirm everything is correct end-to-end, fix whatever is causing incorrect counts

### Re-reviewer Identity (Bug #8)
- **Preserve original re-reviewer** — identity never changes once assigned (primary fix)
- **Nice-to-have:** Track modification history if straightforward to implement
- Research best practices and check existing database/API setup

### Viewer Profile Auto-logout (Bug #4)
- Fix the auto-logout bug
- Follow existing pattern for profile page feedback (no special messaging)

### Claude's Discretion
- Diagnostic logging additions where helpful
- Specific technical implementation approaches
- Whether to add modification history tracking for re-reviewer (based on implementation complexity)

</decisions>

<specifics>
## Specific Ideas

- Error toast with "copy error" feature for bug reporting — make this a general reusable concept
- Follow existing patterns throughout — don't reinvent workflows
- These are primarily debugging tasks requiring deep database/API investigation
- Use Playwright MCP to investigate current UI/UX in running system where relevant

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 55-bug-fixes*
*Context gathered: 2026-01-31*
