# Data Releases: download-first release desk design

**Date:** 2026-07-26
**Surface:** `app/src/views/analyses/DataReleases.vue` and its focused release components

## Problem

The current public route gives the release table and an unfiltered manifest
equal visual priority. On a 1440 px desktop, raw source/version strings wrap
through the archive table. On a 390 px screen, all row fields repeat vertically
before the first download action. A technical reviewer can find the evidence,
but a researcher cannot immediately find the newest release and download it.
The live API also exposed an empty object as a literal `{}` DOI.

## Outcome

Make the selected latest published release the first operational surface:

1. A concise “Latest published release” summary presents release identity,
   publication date, file count, total size, licence, primary bundle download,
   and secondary manifest download.
2. A compact archive lets a visitor select another release without presenting
   hashes, DOI plumbing, or every metadata field as discovery content.
3. File-level downloads stay adjacent to the selected release.
4. Exact identity, hashes, layer lineage, DOI and verification instructions
   remain available in a closed, clearly named technical-verification disclosure.

## Information architecture

```
Page title + purpose
└─ Latest published release (selected detail; primary download)
   ├─ release facts: published, files, size, licence
   ├─ download bundle / manifest
   └─ individual files
└─ Release archive (select a published version)
└─ Technical verification (collapsed by default)
   ├─ exact manifest/provenance
   └─ how to verify
```

The detail initially comes from the existing `getLatestRelease()` request.
Selecting an archive record continues to call `getRelease(id)` and retains the
existing monotonic response guard so a late response cannot replace a newer
selection.

## Visual and interaction contract

- Work inside the existing analysis shell and SysNDD's quiet clinical/research
  visual system: bounded surfaces, token-based colour, compact typography, no
  gradients, dashboards, or decorative illustrations.
- The bundle button is the sole primary action. Manifest and individual-file
  actions are secondary, clearly named actions.
- Archive controls are semantic buttons with an explicit current selection.
  The current release is discoverable to screen readers and visually distinct
  without relying on colour alone.
- On desktop, the archive is compact and near the operational summary. On
  mobile, rows retain only decision-useful facts and controls have 44 px targets.
- Long source-data versions and hashes do not appear in the archive summary;
  exact values remain in technical verification. Visible metadata must never
  stringify malformed runtime values such as `{}`.
- Loading, empty, error, download failure and stale-response behaviour remain
  the existing route behaviour. There are no API, payload, role, or write-action
  changes.

## Accessibility

- Use labelled sections and heading hierarchy for overview, archive, and
  technical verification.
- Ensure a keyboard user can select an archive record and identify the selected
  release using `aria-current`.
- Keep native `<details>` for the technical disclosure.
- Preserve safe http(s)-only external Zenodo link handling and
  `noopener noreferrer`.

## Tests and acceptance criteria

- Unit tests prove malformed DOI-like runtime values render as an unassigned
  value, not an object; release selection calls the correct typed API and the
  latest response cannot overwrite it.
- Component tests prove primary/secondary download affordances, selected archive
  semantics, and 44 px mobile targets.
- A Playwright public-route test checks the latest-release action surface and
  technical disclosure at 1440×900 and 390×844 without invoking any download or
  write action.
- Static Impeccable detection is clean for changed frontend sources; a visual
  review of Playwright screenshots rerates the surface against the audit rubric.

## Deliberate deferrals

- No changes to the public API, release schema, release publishing workflow, or
  server-side DOI serialization are included.
- No release search, filtering, pagination controls, comparison workflow, or
  download telemetry is introduced.
