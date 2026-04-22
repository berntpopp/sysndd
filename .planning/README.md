# Planning

`.planning/` is the single repo-owned planning home for SysNDD. If a planning artifact is part of this repository's durable state, it belongs here. If it is no longer current, it moves under `.planning/_archive/` instead of staying in the live surface.

## Live Surface

These files represent current planning state:

- `PROJECT.md`: durable project context and accumulated decisions
- `STATE.md`: current status snapshot
- `ROADMAP.md`: current roadmap index
- `MILESTONES.md`: milestone history index
- `config.json`: planning metadata
- `*-design.md`: active repo-owned design docs stored in `.planning/`
- `*-plan.md`: active repo-owned implementation plans stored in `.planning/`
- `reviews/`: current review artifacts that still inform active planning
- `superpowers/specs/`: active Superpowers design specs
- `superpowers/plans/`: active Superpowers implementation plans
- `todos/pending/`: active backlog items

## Archive Policy

Archive old material instead of leaving it mixed with active docs.

- historical milestone docs -> `_archive/milestones/`
- legacy plan directories from old root folders -> `_archive/legacy-plans/`
- historical research and synthesis -> `_archive/research/`
- stale codebase snapshots -> `_archive/codebase/`
- review and triage artifacts -> `_archive/reviews/`
- one-off historical plans -> `_archive/one-offs/`
- retained raw payloads -> `_archive/data/`

## Superpowers Boundary

Superpowers-compatible planning artifacts also live inside `.planning/`:

- active specs: `.planning/superpowers/specs/`
- active implementation plans: `.planning/superpowers/plans/`

Use `.planning/` for both repo-owned planning state and Superpowers planning artifacts. Do not create new root-level `.plan/` or `.plans/` folders, and do not put planning specs back under `docs/`.
