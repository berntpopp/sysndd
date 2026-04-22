# Phase 31: Content Management - Context

**Gathered:** 2026-01-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Build CMS editor for ManageAbout page with draft/publish workflow. The existing About page has 7 hardcoded accordion sections (Creators, Citation, Funding, News, Credits, Disclaimer, Contact) that should become editable via a markdown-based CMS. Content loads from database, not hardcoded Vue component.

</domain>

<decisions>
## Implementation Decisions

### Editor experience
- Minimal toolbar: bold, italic, link, headers, lists (essentials only)
- Autosave on blur: saves draft when user clicks away from editor
- Floating markdown cheatsheet: collapsible panel with common syntax reference
- Editor height: Claude's discretion to research best practices and standards

### Preview behavior
- Side-by-side layout: editor left, preview right, always visible together
- Debounced updates: preview refreshes 300ms after user stops typing
- Scroll sync: preview scrolls to match editor cursor position
- Full-screen preview: button to expand preview in modal for full-width view

### Draft workflow
- Per-user drafts: each admin has their own draft, isolated from others
- Full version history: all drafts and published versions tracked
- Silent autosave on navigate: draft saves automatically when leaving page
- No scheduling: publish immediately or save as draft (no future scheduling)

### Content structure
- 7 editable sections: all current accordion sections (Creators, Citation, Funding, News, Credits, Disclaimer, Contact)
- All-or-nothing publishing: single draft covers entire page, publish updates all sections
- Full section control: admins can add new sections, remove existing, and reorder via drag

### Claude's Discretion
- Editor height sizing (research best practices)
- Exact markdown rendering styling
- Section icon selection UI
- Database schema for content versioning
- Drag-and-drop reordering implementation

</decisions>

<specifics>
## Specific Ideas

- Current About.vue has 7 accordion sections with custom icons (bi-people, bi-journal-text, etc.)
- Each section has title and content — preserve this structure in CMS
- News section uses timeline-style formatting with badges and dates
- Citation section has styled card with border-start styling

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 31-content-management*
*Context gathered: 2026-01-25*
