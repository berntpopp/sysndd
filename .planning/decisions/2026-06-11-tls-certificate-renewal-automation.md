# ADR: TLS Certificate Renewal Automation

**Date:** 2026-06-11
**Status:** Proposed (design + safe skeleton; live implementation deferred)
**Refs:** #25

## Context

GitHub issue #25 asks us to automate the yearly TLS certificate lifecycle for
the public SysNDD site. Today the renewal is fully manual:

1. An operator generates a CSR (and private key) by hand once a year.
2. The CSR is emailed to a signing authority.
3. Some days/weeks later the signed certificate is emailed back.
4. An operator installs the new key/cert and restarts the server.

This is slow and bottlenecked on the availability of the specific people who
know how to run step 1 and who hold the mailbox for steps 2–3.

### What the repository tells us about how TLS is served

Two TLS topologies exist in the codebase, reflecting how the deployment has
evolved:

- **Legacy standalone nginx TLS** — `app/docker/nginx/prod.conf` terminates TLS
  on `:443` for `sysndd.org` / `www.sysndd.org`, reading
  `ssl_certificate /etc/nginx/certificates/cert.pem` and
  `ssl_certificate_key /etc/nginx/certificates/key.pem`. `.gitignore` already
  excludes `app/docker/nginx/cert.pem` and `app/docker/nginx/key.pem`. This is
  the deployment the issue's manual workflow was written for: a hand-made CSR is
  emailed out, the returned `cert.pem`/`key.pem` are dropped into the nginx
  certificates mount, and nginx is reloaded. **`prod.conf` is not referenced by
  the current `app/Dockerfile` or any `docker-compose*.yml`** — it is retained
  config from the earlier nginx-terminates-TLS era.
- **Current Traefik stack** — `docker-compose.yml` runs Traefik `v3.7` with a
  single `web` entrypoint on `:80` only. There is **no `websecure`/`:443`
  entrypoint, no ACME resolver, and no certificate mount** in the application
  Compose stack. The public host is `sysndd.dbmr.unibe.ch` (University of Bern,
  DBMR). `documentation/09-deployment.qmd` says only "Use HTTPS in production"
  with no in-stack TLS detail. The practical implication: **TLS is terminated by
  an upstream / institutional reverse proxy in front of this Compose stack**, and
  the institutional CA at Uni Bern is exactly the kind of authority that issues
  via portal/email rather than ACME.

So the renewal target is: produce a key + CSR, get it signed by the
institutional authority, and land the signed certificate wherever the active
TLS terminator reads it (the nginx `cert.pem`/`key.pem` mount in the legacy
topology, or the upstream institutional terminator's certificate store in the
current topology), then reload that terminator.

### Constraints that make this a design + skeleton, not a full automation

- The signing step is an **external** authority reached (per the issue) by
  **email**. It cannot be fully automated or end-to-end tested inside this repo
  without the authority's interface and real secrets.
- Generating/installing real keys is **security-sensitive and
  environment-specific**. Auto-running live key/cert operations from CI or a
  shared agent is unacceptable.
- Therefore the deliverable is a thorough design plus a **dry-run-by-default,
  parameterized** CSR-generation skeleton with clearly-marked operator TODO
  hooks for the deployment-specific submit/install/reload steps. No real keys,
  CSRs, or certificates are generated or committed.

## Options

### Option A — ACME / Let's Encrypt auto-renewal via Traefik (preferred *if* a public CA is acceptable)

Add a `websecure` (`:443`) entrypoint and a Let's Encrypt ACME resolver
(TLS-ALPN-01 or HTTP-01 challenge) to the Traefik stack. Traefik then obtains
and renews certificates automatically; there is **no CSR, no email, no yearly
human step, and no server restart** (Traefik hot-reloads its own certs).

```yaml
# Sketch only — not wired into docker-compose.yml in this change.
command:
  - "--entryPoints.websecure.address=:443"
  - "--certificatesresolvers.le.acme.tlschallenge=true"
  - "--certificatesresolvers.le.acme.email=ops@example.org"
  - "--certificatesresolvers.le.acme.storage=/letsencrypt/acme.json"
# app/api routers: entrypoints=websecure + tls.certresolver=le
# ports: add "443:443"; volume: a persisted acme.json (chmod 600)
```

- **Pros:** Eliminates the manual process entirely; 90-day certs auto-renew;
  no private key ever leaves the host; battle-tested; zero-downtime reload.
- **Cons / preconditions:** Requires (1) a **public CA** to be acceptable to the
  institution for this hostname, (2) inbound `:443` (and `:80` for HTTP-01)
  reachable from the internet for the ACME challenge, and (3) that an upstream
  institutional proxy is **not** already terminating TLS for
  `sysndd.dbmr.unibe.ch` (if it is, ACME must move to that proxy, not this
  stack). Given the `*.unibe.ch` institutional hostname and the issue's
  "signing authority + email" framing, a public CA is likely **not** the
  accepted path for this host — but this must be confirmed with the institution,
  because if it is acceptable it makes the whole issue disappear.

### Option B — Scripted CSR generation + submission + install for an institutional CA (the path this skeleton implements)

Keep the institutional CA but remove the human bottleneck from the mechanical
parts. A small, config-driven script generates the key + CSR reproducibly
(Option B is what `scripts/cert/generate-csr.sh` skeletons). The submit step is
the only genuinely manual/CA-specific part and is left as an operator TODO hook
(portal upload, CA API call, or templated email), because the authority's
interface is not in this repo. Install + reload are also TODO hooks because they
depend on which terminator is active.

- **Pros:** Works with any institutional/internal CA; reproducible CSRs;
  removes "which person knows the openssl incantation" risk; dry-run-safe;
  documented runbook; easy to schedule.
- **Cons:** The submit/receive round-trip with an email-based CA cannot be fully
  automated without the CA's interface; still needs an operator to shepherd the
  signed cert back. A scheduled reminder + pre-generated CSR is the realistic
  win.

## Decision / Recommendation

1. **First, ask the institution whether a public-CA ACME certificate is
   acceptable for `sysndd.dbmr.unibe.ch` (Option A).** If yes, implement Option
   A — it is strictly simpler and fully eliminates issue #25. The follow-up work
   is then a Traefik `:443` + ACME wiring change (or moving ACME to the upstream
   proxy), not the CSR script.
2. **If a public CA is not acceptable (most likely, given the institutional host
   and the email-based signing authority described in the issue), adopt Option
   B.** Use the safe `scripts/cert/generate-csr.sh` skeleton for reproducible
   CSR generation, and have an operator wire the submit/install/reload TODO
   hooks to the Uni Bern authority's actual interface.

This ADR + the skeleton deliver Option B's safe foundation now and document
Option A as the preferred outcome if the institution allows it. **No live
certificate operations and no key material are committed in this change.**

## Yearly schedule mechanism

Whichever option is chosen, the cadence is automated outside the app stack:

- **Option A:** No schedule needed — Traefik renews ACME certs automatically
  (~30 days before expiry).
- **Option B:** A host `cron` entry or a `systemd` timer runs the CSR generator
  on a yearly cadence (e.g. ~6 weeks before expiry to allow round-trip slack)
  and **notifies an operator** (email/Slack) that a fresh CSR is ready to submit.
  Do **not** put cron inside the nginx app container (the repo already forbids
  this for SEO refresh in `09-deployment.qmd`). Example crontab line:

  ```cron
  # 06:00 on Oct 1 each year — generate the renewal CSR and email the operator.
  0 6 1 10 * /opt/sysndd/scripts/cert/generate-csr.sh --apply \
    --out-dir /etc/sysndd/certs >> /var/log/sysndd-cert-renew.log 2>&1
  ```

  An expiry-driven check (`openssl x509 -checkend`) can replace the fixed date so
  generation triggers from the *current* cert's `notAfter` rather than a guessed
  month.

## Where keys/certs live

- **Private key + CSR output:** an operator-managed directory **outside the git
  tree**, default `CERT_OUT_DIR=/etc/sysndd/certs`. The skeleton hard-refuses to
  write inside the repository working tree.
- **Active certificate/key for the terminator:**
  - Legacy nginx topology: `cert.pem` / `key.pem` mounted at
    `/etc/nginx/certificates/` (already gitignored under
    `app/docker/nginx/`).
  - Current/upstream topology: the institutional proxy's certificate store
    (operator-specific; outside this repo).
  - Option A (ACME): Traefik's persisted `acme.json` (chmod 600), never a repo
    path.

## How the server picks up the new cert (reload vs restart)

- **nginx:** `nginx -s reload` (or `docker compose exec <proxy> nginx -s reload`)
  re-reads `cert.pem`/`key.pem` **without dropping connections** — prefer reload
  over a full container restart.
- **Traefik file-provider:** dynamic certificate files **hot-reload
  automatically** on change; no restart.
- **Traefik ACME (Option A):** fully automatic; nothing to do.

The original issue's "restart the server" step becomes a graceful **reload** in
all modern paths.

## Security considerations

- **Never commit key material.** Keys/CSRs are written only to `CERT_OUT_DIR`
  outside the repo; the skeleton refuses repo-internal paths;
  `scripts/cert/cert-renewal.conf` (real, site-specific config) is gitignored
  (only `cert-renewal.conf.example` is tracked, and it holds no secrets).
- **Filesystem permissions:** private keys are written under `umask 077` and
  `chmod 600`; the ACME store (`acme.json`) must also be `0600`.
- **Secrets handling:** CA credentials/tokens (if the CA exposes an API) live in
  the operator's `.env`/secret store, never in the repo. The config file holds
  only non-secret subject metadata.
- **No secret logging:** the script logs the CSR path (safe to share) and never
  prints the private key.
- **Reduced blast radius:** automating CSR generation removes ad-hoc "copy this
  openssl command from a wiki" steps that invite mistakes.

## Rollback plan

- Always retain the **previous** `cert.pem`/`key.pem` (and ACME store) as `.bak`
  before installing a new pair. The install TODO hook documents this.
- If the new certificate fails validation or breaks TLS after reload, restore
  the `.bak` pair and reload again — this is fast and connection-preserving.
- Verify before and after with:
  ```bash
  echo | openssl s_client -connect sysndd.dbmr.unibe.ch:443 \
    -servername sysndd.dbmr.unibe.ch 2>/dev/null | openssl x509 -noout -dates
  ```
- The newly generated key/CSR are inert until an operator installs the signed
  cert, so generation itself carries no production risk.

## Out of scope for this change

- Wiring `:443`/ACME into `docker-compose.yml` (Option A implementation).
- Implementing the CA-specific submit transport, the signed-cert install, and
  the proxy reload (the three operator TODO hooks in the skeleton).
- Any live key/cert/CSR generation.

These are the recommended follow-up once the institution answers the Option A
question and the operator confirms the active TLS terminator.
