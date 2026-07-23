<p align="center">
  <a href="https://sysndd.dbmr.unibe.ch/">
    <img src="app/public/img/icons/android-chrome-192x192.png" alt="SysNDD logo" width="128" height="128">
  </a>
</p>

<h1 align="center">SysNDD</h1>

<p align="center">
  The expert-curated database of gene–inheritance–disease relationships in
  <strong>neurodevelopmental disorders</strong> (NDD).
</p>

<!-- Status badges -->
<p align="center">
  <a href="https://github.com/berntpopp/sysndd/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/berntpopp/sysndd/ci.yml?branch=master&label=CI&logo=github" alt="CI status"></a>
  <a href="CHANGELOG.md"><img src="https://img.shields.io/github/package-json/v/berntpopp/sysndd?filename=app%2Fpackage.json&label=version&color=blue" alt="Version"></a>
  <!-- Frontend Vitest line coverage; regenerate with `cd app && npm run test:coverage` -->
  <a href="#testing--quality"><img src="https://img.shields.io/badge/coverage-59%25%20(app)-yellow" alt="App test coverage"></a>
  <a href="LICENSE.md"><img src="https://img.shields.io/badge/code-MIT--0-green" alt="Code license: MIT-0"></a>
  <a href="https://creativecommons.org/licenses/by/4.0/"><img src="https://img.shields.io/badge/data-CC%20BY%204.0-orange" alt="Data license: CC BY 4.0"></a>
</p>

<!-- Stack badges -->
<p align="center">
  <img src="https://img.shields.io/badge/Vue-3.5-4FC08D?logo=vuedotjs&logoColor=white" alt="Vue 3.5">
  <img src="https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white" alt="TypeScript">
  <img src="https://img.shields.io/badge/Vite-7-646CFF?logo=vite&logoColor=white" alt="Vite 7">
  <img src="https://img.shields.io/badge/R%204.6-Plumber-276DC3?logo=r&logoColor=white" alt="R / Plumber">
  <img src="https://img.shields.io/badge/MySQL-8.4-4479A1?logo=mysql&logoColor=white" alt="MySQL 8.4">
  <img src="https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white" alt="Docker Compose">
</p>

<p align="center">
  <a href="https://sysndd.dbmr.unibe.ch/">Live site</a> ·
  <a href="https://berntpopp.github.io/sysndd/">Documentation</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="https://github.com/berntpopp/sysndd/discussions">Discussions</a>
</p>

---

SysNDD curates gene–inheritance–disease relationships in NDD with a defined evidence
model and versioned review workflow. This monorepo holds the three code trees that run
the public site at [sysndd.dbmr.unibe.ch](https://sysndd.dbmr.unibe.ch/), plus the
rendered documentation book.

## Repository layout

| Directory        | Stack                         | What it is                                                      |
| ---------------- | ----------------------------- | --------------------------------------------------------------- |
| `app/`           | Vue 3.5 · TypeScript · Vite 7 | Single-page web application (browse, filter, analyze, download) |
| `api/`           | R · Plumber · `renv`          | REST API, background workers, optional read-only MCP sidecar    |
| `db/`            | MySQL 8.4                     | Schema, data-prep scripts, and versioned migrations             |
| `documentation/` | Quarto                        | Documentation book published to GitHub Pages                    |

Each directory has its own `README.md` with more detail.

## Quick start

**Prerequisites:** [Docker](https://docs.docker.com/get-docker/) with Compose v2, Git,
and GNU Make. For host-side work you also need Node.js (see [`app/.nvmrc`](app/.nvmrc))
and R.

### Full development stack (recommended)

Brings up the app, API, workers, and databases together via Docker:

```bash
git clone https://github.com/berntpopp/sysndd.git
cd sysndd
make install-dev
make doctor
make dev
```

After `make dev` the stack is reachable at:

| Service           | URL / port                |
| ----------------- | ------------------------- |
| App (Vite)        | http://localhost:5173     |
| API (direct)      | http://localhost:7778     |
| Traefik dashboard | http://localhost:8090     |
| MySQL dev / test  | `localhost:7654` / `7655` |

See [Development](https://berntpopp.github.io/sysndd/08-development.html) for the full
onboarding guide.

### Frontend-only iteration

To iterate on the SPA against an already-running API:

```bash
cd app
npm install --legacy-peer-deps
npm run dev                 # http://localhost:5173
```

> **Deploying SysNDD?** Operator setup, secrets, backups, migrations, and release
> runbooks live in the
> [Deployment guide](https://berntpopp.github.io/sysndd/09-deployment.html) — not here.

## Testing & quality

```bash
cd app && npm run test:unit     # frontend unit tests (Vitest)
make test-api                   # R API tests (testthat)
make pre-commit                 # fast pre-push gate
make ci-local                   # closest local mirror of CI
```

The frontend suite is **2,129 Vitest tests** at **~59% line coverage**
(`cd app && npm run test:coverage`); the R API is covered by `testthat`. Continuous
integration runs lint, type-check, unit tests, the R API gate, a bundle-budget check,
and a production smoke test — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).
Contribution and coding conventions are in [CONTRIBUTING.md](CONTRIBUTING.md) and the
shared agent instructions in [AGENTS.md](AGENTS.md).

## Documentation

The full documentation is published at
[berntpopp.github.io/sysndd](https://berntpopp.github.io/sysndd/):

- [Introduction](https://berntpopp.github.io/sysndd/01-intro.html)
- [Web tool guide](https://berntpopp.github.io/sysndd/02-web-tool.html)
- [API](https://berntpopp.github.io/sysndd/03-api.html)
- [Database structure](https://berntpopp.github.io/sysndd/04-database-structure.html)
- [Curation criteria](https://berntpopp.github.io/sysndd/05-curation-criteria.html)
- [Development](https://berntpopp.github.io/sysndd/08-development.html) ·
  [Deployment](https://berntpopp.github.io/sysndd/09-deployment.html)
- [Tutorial videos](https://berntpopp.github.io/sysndd/07-tutorial-videos.html)

## Contributing and community

To help curate entries, register for a reviewer/curator
[account](https://sysndd.dbmr.unibe.ch/Register). Ask questions, report bugs, and
discuss SysNDD in [GitHub Discussions](https://github.com/berntpopp/sysndd/discussions).
For technical problems or data requests, contact us at `support [at] sysndd.org`.

## Creators and contributors

- **Bernt Popp** (SysNDD) — [ORCID](https://orcid.org/0000-0002-3679-1081) ·
  [GitHub](https://github.com/berntpopp) · [web](https://www.berntpopp.com)
- **Christiane Zweier** (SysID, SysNDD) — [ORCID](https://orcid.org/0000-0001-8002-2020)
- **Annette Schenck** (SysID) — [ORCID](https://orcid.org/0000-0002-6918-3314) ·
  [lab](https://www.schencklab.com)
- **Melek Firat Altay** (SysNDD) — [ORCID](https://orcid.org/0000-0002-8174-5631) ·
  [GitHub](https://github.com/altay-epfl)

<details>
<summary><strong>Support and funding</strong></summary>

SysNDD development is supported by:

- DFG (Deutsche Forschungsgemeinschaft) grant PO2366/2-1 to Bernt Popp.
- DFG grant ZW184/6-1 to Christiane Zweier.
- ITHACA ERN, through Alain Verloes.

The previous SysID database and data curation was supported by:

- The European Union's FP7 large-scale integrated network GenCoDys (HEALTH-241995), Martijn A. Huynen and Annette Schenck.
- VIDI and TOP grants (917-96-346, 912-12-109) from the Netherlands Organisation for Scientific Research (NWO) to Annette Schenck.
- DFG grants ZW184/1-1 and -2 to Christiane Zweier.
- The IZKF (Interdisziplinäres Zentrum für Klinische Forschung) Erlangen to Christiane Zweier.
- ZonMw grant (NWO, 907-00-365) to Tjitske Kleefstra.

</details>

<details>
<summary><strong>Credits and acknowledgements</strong></summary>

We acknowledge Martijn Huynen and members of the Huynen and Schenck groups at the
Radboud University Medical Center Nijmegen, The Netherlands, for building SysID and
supporting it for many years, and all past users of SysID for their constructive
feedback. Alain Verloes and ERN ITHACA provide valuable encouragement and support by
initiating and supporting the data integration with Orphanet and helping recruit expert
curators.

</details>

## License

- **Code** — [MIT No Attribution (MIT-0)](LICENSE.md).
- **Data, website, and API usage** — [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
