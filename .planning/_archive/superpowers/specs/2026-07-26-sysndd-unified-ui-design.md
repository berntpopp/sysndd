# SysNDD unified UI design specification

**Status:** Draft for approval — planning only; no application code is authorized by this document.

## Purpose and evidence

SysNDD is an **Operate** surface for clinical and research data work. The interface must let clinicians, curators, reviewers, and researchers scan evidence and complete authorised actions accurately. Trust, accessibility, and efficient comparison outrank visual novelty.

This specification is based on the 2026-07-26 app-wide audit and home-page critique, the existing visual guide, source review, and a fresh read-only Playwright check at 1440x900 and 390x844. The live check reproduced: duplicate `main` landmarks on Home, Data Releases, and Gene Networks; unnamed header/footer navigation; three unfocusable horizontally scrollable MCP code regions; an under-specified Gene Networks splitter; and `article[role=listitem]` mobile records. It found no body-level horizontal overflow on the sampled routes.

## Product direction

- Preserve the current quiet medical blue/teal language, scientific monospace identifiers, compact tables, status badges, and role-gated workflows. Do not recolour clinical status, inheritance, cluster, or scientific-visualisation encodings without a documented domain meaning and contrast check.
- Make shared primitives the authority: one document `main`, named navigation landmarks, one route `h1`, labelled controls, semantic tables/lists, and predictable loading/empty/error feedback.
- Keep desktop data work table-first. On phones, replace operational tables whose actions or decision state cannot fit in the first visible region with compact record rows. Public read-only data remains compact; curation, review, and administration expose the primary action without horizontal discovery work.
- Remove visual noise, not information: one bounded primary task surface, light borders, modest 6–8px radius, compact headings, and explicit action hierarchy. Decorative side stripes and layout-property animation are not a component language.

## Durable visual language

### Semantic tokens

Keep primitive palette tokens and introduce semantic aliases, consumed by shared primitives first:

| Concern | Semantic tokens / contract |
|---|---|
| Surfaces | `--surface-canvas`, `--surface-raised`, `--surface-subtle`, `--surface-status-*`; white/near-white only for routine operational surfaces. |
| Text | `--text-primary`, `--text-secondary`, `--text-muted`, `--text-on-action`; normal text meets 4.5:1, utility text is never below 12px. |
| Borders/focus | `--border-subtle`, `--border-strong`, existing visible focus ring; no dark card borders. |
| Actions | `--action-primary`, `--action-secondary`, `--action-danger` and their focus/hover states; colour never carries action or status meaning alone. |
| Status/science | Existing success/warning/danger/info, inheritance, cluster, and chart colours retain their domain contracts; use labelled chips/icons and status surfaces rather than arbitrary local pastels. |

### Type, spacing, and surfaces

- Type: route title 18–22px semibold; section title 16–18px; control/table label 12–14px semibold; body/table data 14–16px; identifiers use the existing mono stack. No negative tracking.
- Spacing: 4 / 8 / 12 / 16 / 24 / 32px steps. Dense controls use 8px gaps, form groups 12px, and task sections 24–32px.
- Surface hierarchy: canvas → one primary frame/table shell → optional repeated record rows or disclosure panels. Nested cards are reserved for repeated records, never generic layout.
- Feedback: loading, empty, error, and unavailable snapshot states stay within the affected shell; every recoverable error offers a safe retry where the existing data contract supports one.

### Interaction and responsive policy

- **Controls:** all operational icon/buttons and row actions have a 44x44 CSS-pixel hit area on touch layouts; compact glyphs may remain visually compact inside that area. Preserve desktop table density where a mouse/keyboard workflow needs it.
- **Forms and tables:** use visible labels where practical; otherwise provide precise programmatic labels such as `Filter users by role` and `Rows per page`. Table filter cells remain presentational while the controls are named.
- **Mobile records:** use a real `ul > li` or a consistent ARIA list with non-article list items. Each operational row has identity, decision-relevant metadata, status chips, and a stable action cluster. If a table remains horizontally scrollable, announce the scroll region and keep the primary action visible.
- **Motion:** state changes use colour, text, and focus independently of motion. Do not animate width/height/layout for low-value decoration; respect the existing reduced-motion contract.
- **Accessibility:** one top-level `main`; named Primary/Footer/section navigation; route-level `h1`; keyboard-operable scroll regions and separator; no invalid ARIA roles; visible focus and WCAG 2.2 AA contrast.

## Scope and guardrails

- In scope: shared shell semantics, labelled controls, public/mobile list semantics, accessible splitter and code blocks, mobile administrative/curation row variants, semantic-token adoption in shared primitives, and removal of verified visual drift.
- Explicitly preserved: API routes and response shapes, typed API clients, Pinia/auth implementation, backend role enforcement, curation/review state machines, clinical terminology, database content, existing public table filtering/sorting, and scientific visualisations.
- No data-changing Playwright interaction; tests authenticate only through existing fixtures and must not submit mutation actions.
- The application remains a Vue 3 + TypeScript + BootstrapVueNext app. No new UI library or broad route rewrite is proposed.

## Outcome measures

1. Axe/manual landmark checks report one `main`, named navigation, valid roles, named controls, focusable code regions, and operable Gene Networks separator on the affected routes at desktop and 390px.
2. Curation/admin mobile workflows expose their primary row actions without a required horizontal scroll; sampled operational controls meet the 44px target.
3. Shared shells use semantic surface/text/border/action tokens; decorative side-accent findings and `transition: width` are gone or deliberately documented as domain-semantic.
4. Existing role checks, typed client boundaries, public table behaviour, and clinical status meanings remain unchanged, proven by targeted unit/E2E tests and strict type-checking.

## Deliberate deferrals

- Home-page content/provenance copy, search onboarding, and disclosure-dialog information architecture need clinical/product-owner wording approval; they are not folded into a visual-system pass.
- A full one-for-one removal of all 1,400+ literal colours is unsafe and out of scope. The migration begins with semantic primitives and repeated local patterns; status and scientific palettes are reviewed individually.
- Large workflow redesigns (Manage About CMS, LLM dashboard information architecture, re-review action-count reduction) remain separate product work after this foundation is in place.
