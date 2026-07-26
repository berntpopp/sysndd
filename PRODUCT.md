# SysNDD product context

<!-- impeccable:product-schema 1 -->

## Platform

Public web application.

## Users

- Researchers who need a current, reproducible export of SysNDD-derived analysis.
- Technical reviewers who need to inspect provenance, checksums, and release lineage.

## Product purpose

SysNDD is a neurodevelopmental-disorder gene–disease database. Its public
analysis-snapshot releases are immutable, content-addressed exports of the
public functional-cluster, phenotype-cluster, and correlation analyses.

## Operating context

The `/DataReleases` route is unauthenticated and read-only. It obtains release
heads and release detail through the typed frontend analysis client, then lets a
visitor download a bundle, manifest, or an individual published file. The
existing API payload and public-only boundary are product contracts.

## Product principles

- Put the most likely research task—getting the latest valid release—first.
- Keep technical evidence available and exact without forcing it into the
  initial scanning path.
- Use the established compact, quiet, table-first SysNDD design language.
- Preserve semantic scientific and clinical colour meaning; do not introduce
  marketing decoration or new colour semantics.
- Make the route workable at 390 px as well as on a research desktop.
- Treat downloads and provenance as trustworthy operational tools: clear
  labels, stable selection, safe outbound links, and no hidden state changes.

## Evidence

These statements are grounded in the repository's release API/types, the
existing route, the visual design guide, and live local inspection on 2026-07-26.
