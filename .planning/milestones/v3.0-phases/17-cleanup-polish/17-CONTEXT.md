# Phase 17: Cleanup & Polish - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Finalize the Vue 3 + TypeScript migration by removing @vue/compat compatibility layer, cleaning all legacy code, optimizing bundle for production, meeting performance targets, verifying browser compatibility, and updating documentation. This is the production-readiness phase — no new features, just polish.

</domain>

<decisions>
## Implementation Decisions

### Bundle optimization targets
- Hard limit: < 2MB gzipped (must meet, block release if over)
- Exception: If meeting limit requires cutting features, soften limit instead — no feature cuts
- Code splitting: Keep critical path fast (landing, gene, entity, disease pages load quickly)
- Lazy-load heavy libs (UpSet.js, treeselect) only for non-critical features
- Create detailed BUNDLE-ANALYSIS.md with size breakdown, recommendations, and optimization history

### Documentation scope
- README: Minimal update with new stack and commands
- documentation/ folder: Comprehensive developer guide
  - Local setup and development workflow
  - Running tests and debugging tips
  - Component patterns and composables usage
  - Folder structure and architecture
  - Coding conventions and PR process
  - Deployment notes
- CHANGELOG.md: Detailed changelog with all major changes, breaking changes, and upgrade notes
- Existing docs: Update in place (no archiving, no removal)

### Legacy removal strategy
- Remove everything unused — aggressive cleanup, git history is the backup
- Delete all dead code, unused files, commented blocks
- @vue/compat removal: Fix all remaining Vue 2 patterns (no flagging, no TODOs)
- npm audit: Fix all vulnerabilities, even if breaking changes require investigation
- Dependency cleanup: Remove all unused packages (webpack, vue-cli, etc.)

### Performance thresholds
- Lighthouse target: 100 in all categories (Performance, Accessibility, Best Practices, SEO)
- Test pages: Landing page + key data views (gene view, entity view, disease view)
- Trade-offs: If 100 can't be met, file GitHub issues for future improvement backlog

### Claude's Discretion
- Specific order of cleanup operations
- Which Lighthouse issues to prioritize when fixing
- How to structure BUNDLE-ANALYSIS.md sections
- Browser testing methodology

</decisions>

<specifics>
## Specific Ideas

- "All 100" Lighthouse scores — user wants perfection, not just passing
- documentation/ folder (not docs/) is the existing location for developer docs
- Medical app context: reliability and accessibility are critical for clinical use

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 17-cleanup-polish*
*Context gathered: 2026-01-23*
