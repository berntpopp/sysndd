# Public MCP Access Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the opt-in SysNDD MCP endpoint intentionally public and credential-free while preserving browser navigation, read-only isolation, and bounded/observable edge behavior.

**Architecture:** Traefik routes only exact-path MCP-shaped traffic over a dedicated internal ingress network, leaving normal browser GET navigation on the Vue page and leaving MCP without internet egress. Fixed shared-rate, POST body/concurrency, and read-time bounds protect the single R process; MCP-only access logs make edge rejections observable without logging payloads.

**Tech Stack:** Docker Compose, Traefik 3.7.3, Bash/Docker/curl/jq smoke testing, R/testthat/yaml, Vue 3/TypeScript, BootstrapVueNext, Vitest, Playwright, Quarto Markdown.

**Spec:** `docs/superpowers/specs/2026-08-27-public-mcp-access-design.md`

## Global Constraints

- Production MCP is public and credential-free only while every tool remains approved-public and read-only.
- The MCP container must remain on internal-only networks and receive no internet egress.
- Traefik is pinned to v3.7.3 because the privacy-preserving query-parameter access-log setting is unavailable in earlier 3.7 patch releases; router rules use `HeaderRegexp`, singular.
- The shared limiter is exactly 120 requests/minute per request Host with burst 20.
- POST is capped at four in-flight requests per request Host and 256 KiB bodies.
- The `web` entrypoint whole-request read timeout is explicitly 60 seconds.
- MCP access logs must omit bodies, headers, query parameters, `ClientAddr`, and `ClientHost`; application and Traefik-internal routers remain opted out.
- Standalone SSE, sessions, direct-browser CORS, `/mcp/`, OAuth, and per-user identity are non-goals.
- `MCP_ALLOWED_ORIGINS` exactly allows the canonical production Origin; absent Origin remains accepted, while empty, malformed, and untrusted values fail closed.
- Do not load-test production.

---

## File Structure

- Modify `api/tests/testthat/test-mcp-select-principal-compose.R`: parse exact Compose structure and scope documentation/policy assertions.
- Modify `api/services/mcp-tools.R` and `api/tests/testthat/test-mcp-tools.R`: replace the localhost-only upstream Origin validator with an exact configurable fail-closed allowlist.
- Modify `.env.example`: document the canonical `MCP_ALLOWED_ORIGINS` value.
- Create `scripts/tests/test-mcp-traefik-edge.sh`: run the resolved production labels against disposable app/MCP stubs and Traefik 3.7.
- Modify `Makefile`: expose the isolated edge smoke as `test-mcp-edge`.
- Modify `docker-compose.yml`: add the internal edge network, exact routers, controls, timeout, and MCP-only access logging.
- Modify `docker-compose.override.yml`: correct the development-network comment after the base topology changes.
- Modify `app/src/views/help/McpInfoView.spec.ts`: specify public/no-auth and fair-use copy with normalized whitespace.
- Modify `app/src/views/help/McpInfoView.vue`: remove protected/bearer instructions and describe the public contract accurately.
- Modify `app/tests/e2e/mcp-info.spec.ts`: update browser-page expectations and the environment-gated protocol comment.
- Modify `AGENTS.md`: replace the canonical protected-only reachability policy while retaining every read-only invariant.
- Modify `documentation/03-api.qmd`: describe public runtime behavior and edge bounds.
- Modify `documentation/09-deployment.qmd`: replace the protected overlay, document isolation/limits/logging, and correct Operations Notes.
- Modify `CHANGELOG.md`: record the #629 correction under Unreleased.

### Task 1: Freeze and Implement the Public Traefik Edge

**Files:**
- Modify: `api/tests/testthat/test-mcp-select-principal-compose.R`
- Create: `scripts/tests/test-mcp-traefik-edge.sh`
- Modify: `Makefile`
- Modify: `docker-compose.yml`

**Interfaces:**
- Consumes: the existing `mcp`, `app`, and `traefik` Compose services.
- Produces: exact `mcp-post`/`mcp-get` routers, service `mcp`, middleware names `mcp-shared-rate`, `mcp-post-body`, `mcp-post-inflight`, and `mcp-strip`, plus `make test-mcp-edge`.

- [ ] **Step 1: Add structured Compose-test helpers**

Append these helpers after `.mcp_compose_service_block()` in `api/tests/testthat/test-mcp-select-principal-compose.R`:

```r
.mcp_compose_model <- function() {
  yaml::read_yaml(file.path(.mcp_compose_repo_root, "docker-compose.yml"))
}

.mcp_compose_label_map <- function(service) {
  labels <- unlist(service$labels, use.names = FALSE)
  stopifnot(is.character(labels), is.null(names(labels)))
  parts <- strsplit(labels, "=", fixed = TRUE)
  keys <- vapply(parts, `[[`, character(1), 1L)
  values <- vapply(parts, function(x) paste(x[-1L], collapse = "="), character(1))
  stats::setNames(values, keys)
}
```

- [ ] **Step 2: Add the failing exact Compose contract test**

Append:

```r
test_that("MCP profile exposes a bounded credential-free transport without egress", {
  model <- .mcp_compose_model()
  mcp <- model$services$mcp
  traefik <- model$services$traefik
  labels <- .mcp_compose_label_map(mcp)

  expect_identical(traefik$image, "traefik:v3.7.3")
  expect_setequal(unlist(mcp$networks), c("backend", "mcp_edge"))
  expect_false("proxy" %in% unlist(mcp$networks))
  expect_true("mcp_edge" %in% unlist(traefik$networks))
  expect_true(isTRUE(model$networks$mcp_edge$internal))
  expect_identical(model$networks$mcp_edge$name, "sysndd_mcp_edge")

  expected <- c(
    "traefik.enable" = "true",
    "traefik.docker.network" = "sysndd_mcp_edge",
    "traefik.http.routers.mcp-post.rule" =
      "Host(`sysndd.dbmr.unibe.ch`) && Path(`/mcp`) && Method(`POST`)",
    "traefik.http.routers.mcp-post.entrypoints" = "web",
    "traefik.http.routers.mcp-post.priority" = "200",
    "traefik.http.routers.mcp-post.service" = "mcp",
    "traefik.http.routers.mcp-post.middlewares" =
      "mcp-shared-rate,mcp-post-body,mcp-post-inflight,mcp-strip",
    "traefik.http.routers.mcp-post.observability.accesslogs" = "true",
    "traefik.http.routers.mcp-get.rule" =
      paste0(
        "Host(`sysndd.dbmr.unibe.ch`) && Path(`/mcp`) && Method(`GET`) && ",
        "HeaderRegexp(`Accept`, `(?i)(^|[[:space:],])text/event-stream",
        "([[:space:];,]|$)`)"
      ),
    "traefik.http.routers.mcp-get.entrypoints" = "web",
    "traefik.http.routers.mcp-get.priority" = "200",
    "traefik.http.routers.mcp-get.service" = "mcp",
    "traefik.http.routers.mcp-get.middlewares" = "mcp-shared-rate,mcp-strip",
    "traefik.http.routers.mcp-get.observability.accesslogs" = "true",
    "traefik.http.middlewares.mcp-shared-rate.ratelimit.average" = "120",
    "traefik.http.middlewares.mcp-shared-rate.ratelimit.period" = "1m",
    "traefik.http.middlewares.mcp-shared-rate.ratelimit.burst" = "20",
    "traefik.http.middlewares.mcp-shared-rate.ratelimit.sourcecriterion.requesthost" = "true",
    "traefik.http.middlewares.mcp-post-body.buffering.maxrequestbodybytes" = "262144",
    "traefik.http.middlewares.mcp-post-inflight.inflightreq.amount" = "4",
    "traefik.http.middlewares.mcp-post-inflight.inflightreq.sourcecriterion.requesthost" = "true",
    "traefik.http.middlewares.mcp-strip.stripprefix.prefixes" = "/mcp",
    "traefik.http.services.mcp.loadbalancer.server.port" = "8787"
  )

  expect_identical(labels[names(expected)], expected)
  expect_false(any(grepl(
    "basic.?auth|forward.?auth|oauth|bearer|mcp-auth",
    paste(names(labels), labels),
    ignore.case = TRUE
  )))

  command <- unlist(traefik$command, use.names = FALSE)
  expect_true("--entryPoints.web.transport.respondingTimeouts.readTimeout=60s" %in% command)
  expect_true("--accesslog=true" %in% command)
  expect_true("--accesslog.format=json" %in% command)
  expect_true("--accesslog.fields.headers.defaultmode=drop" %in% command)
  expect_true("--accesslog.fields.queryparameters.defaultmode=drop" %in% command)
  expect_true("--entryPoints.web.observability.accessLogs=false" %in% command)
})
```

- [ ] **Step 3: Add the isolated live-Traefik smoke before changing Compose**

Create executable `scripts/tests/test-mcp-traefik-edge.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SUFFIX="$$-${RANDOM}"
NETWORK="sysndd-mcp-edge-test-${SUFFIX}"
TRAEFIK="sysndd-mcp-traefik-test-${SUFFIX}"
MCP="sysndd-mcp-backend-test-${SUFFIX}"
APP="sysndd-mcp-app-test-${SUFFIX}"

cleanup() {
  docker rm -f "${TRAEFIK}" "${MCP}" "${APP}" >/dev/null 2>&1 || true
  docker network rm "${NETWORK}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for command in docker jq curl; do
  command -v "${command}" >/dev/null || {
    echo "[mcp-edge] missing required command: ${command}" >&2
    exit 1
  }
done

cd "${ROOT_DIR}"
MODEL="$(docker compose -f docker-compose.yml --env-file .env.example \
  --profile mcp config --format json 2>/dev/null)"

mapfile -t MCP_LABELS < <(
  jq -r '.services.mcp.labels | to_entries[] | "\(.key)=\(.value)"' <<<"${MODEL}"
)
mapfile -t APP_LABELS < <(
  jq -r '.services.app.labels | to_entries[] | "\(.key)=\(.value)"' <<<"${MODEL}"
)
mapfile -t TRAEFIK_COMMAND < <(
  jq -r '.services.traefik.command[]' <<<"${MODEL}"
)
TRAEFIK_IMAGE="$(jq -r '.services.traefik.image' <<<"${MODEL}")"

if ((${#MCP_LABELS[@]} == 0)); then
  echo "[mcp-edge] resolved MCP service has no Traefik labels" >&2
  exit 1
fi

MCP_ARGS=()
for label in "${MCP_LABELS[@]}"; do
  if [[ "${label}" == traefik.docker.network=* ]]; then
    label="traefik.docker.network=${NETWORK}"
  fi
  MCP_ARGS+=(--label "${label}")
done
MCP_ARGS+=(--label "sysndd.mcp-edge-smoke=${SUFFIX}")
APP_ARGS=()
for label in "${APP_LABELS[@]}"; do
  APP_ARGS+=(--label "${label}")
done
APP_ARGS+=(--label "sysndd.mcp-edge-smoke=${SUFFIX}")

read -r -d '' STUB <<'PY' || true
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os

role = os.environ["ROLE"]
port = int(os.environ["PORT"])

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_args):
        return

    def reply(self, status, body, content_type):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if role == "app":
            self.reply(200, b"SYSNDD-APP", "text/html")
        else:
            self.reply(405, b"method not allowed", "text/plain")

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        self.rfile.read(length)
        if role == "mcp":
            self.reply(200, b'{"jsonrpc":"2.0","id":1,"result":{"server":"MCP-STUB"}}', "application/json")
        else:
            self.reply(405, b"method not allowed", "text/plain")

ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
PY

docker network create "${NETWORK}" >/dev/null
docker run -d --name "${MCP}" --network "${NETWORK}" \
  -e ROLE=mcp -e PORT=8787 "${MCP_ARGS[@]}" \
  python:3-alpine python -u -c "${STUB}" >/dev/null
docker run -d --name "${APP}" --network "${NETWORK}" \
  -e ROLE=app -e PORT=8080 "${APP_ARGS[@]}" \
  python:3-alpine python -u -c "${STUB}" >/dev/null
docker run -d --name "${TRAEFIK}" --network "${NETWORK}" \
  -p 127.0.0.1::80 -p 127.0.0.1::8080 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  "${TRAEFIK_IMAGE}" "${TRAEFIK_COMMAND[@]}" \
  --providers.docker.network="${NETWORK}" \
  --providers.docker.constraints="Label(\`sysndd.mcp-edge-smoke\`, \`${SUFFIX}\`)" \
  --log.level=ERROR >/dev/null

WEB_PORT="$(docker port "${TRAEFIK}" 80/tcp | awk -F: 'NR == 1 { print $NF }')"
API_PORT="$(docker port "${TRAEFIK}" 8080/tcp | awk -F: 'NR == 1 { print $NF }')"
BASE="http://127.0.0.1:${WEB_PORT}"

for _ in $(seq 1 40); do
  if curl -fsS "http://127.0.0.1:${API_PORT}/api/http/routers" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

ROUTERS="$(curl -fsS "http://127.0.0.1:${API_PORT}/api/http/routers")"
jq -e '[.[] | select(.name == "mcp-post@docker" and .status == "enabled")] | length == 1' \
  <<<"${ROUTERS}" >/dev/null
jq -e '[.[] | select(.name == "mcp-get@docker" and .status == "enabled")] | length == 1' \
  <<<"${ROUTERS}" >/dev/null

HTML="$(curl -fsS -H 'Host: sysndd.dbmr.unibe.ch' -H 'Accept: text/html' "${BASE}/mcp")"
[[ "${HTML}" == "SYSNDD-APP" ]]

POST="$(curl -fsS -H 'Host: sysndd.dbmr.unibe.ch' \
  -H 'Content-Type: application/json' -X POST --data '{}' "${BASE}/mcp")"
jq -e '.result.server == "MCP-STUB"' <<<"${POST}" >/dev/null

GET_STATUS="$(curl -sS -o /dev/null -w '%{http_code}' \
  -H 'Host: sysndd.dbmr.unibe.ch' \
  -H 'Accept: application/json, Text/Event-Stream; q=1' "${BASE}/mcp")"
[[ "${GET_STATUS}" == "405" ]]

INVALID_ACCEPT="$(curl -fsS -H 'Host: sysndd.dbmr.unibe.ch' \
  -H 'Accept: application/x-text/event-stream-foo' "${BASE}/mcp")"
[[ "${INVALID_ACCEPT}" == "SYSNDD-APP" ]]

BODY_STATUS="$(head -c 300000 /dev/zero | tr '\0' x | curl -sS -o /dev/null \
  -w '%{http_code}' -H 'Host: sysndd.dbmr.unibe.ch' \
  -H 'Content-Type: application/json' -X POST --data-binary @- "${BASE}/mcp")"
[[ "${BODY_STATUS}" == "413" ]]

RATE_LIMITED=0
for _ in $(seq 1 80); do
  status="$(curl -sS -o /dev/null -w '%{http_code}' \
    -H 'Host: sysndd.dbmr.unibe.ch' -H 'Content-Type: application/json' \
    -X POST --data '{}' "${BASE}/mcp")"
  if [[ "${status}" == "429" ]]; then
    RATE_LIMITED=1
    break
  fi
done
[[ "${RATE_LIMITED}" == "1" ]]

# Poll `docker logs` for `mcp-post@docker`, prove `app@docker` is absent,
# and prove header/body/query sentinels plus ClientAddr/ClientHost are absent.
echo "[mcp-edge] PASS: routing, 405/413/429 controls, and privacy-bounded MCP-only logs verified"
```

- [ ] **Step 4: Add the smoke target**

Add `test-mcp-edge` to the Makefile `.PHONY` declaration and add:

```make
test-mcp-edge: ## [test] #629: verify public MCP routing and edge controls in disposable Traefik
	@bash $(ROOT_DIR)/scripts/tests/test-mcp-traefik-edge.sh
```

- [ ] **Step 5: Run both new checks and verify RED**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-select-principal-compose.R')"
make test-mcp-edge
```

Expected: the R contract fails on missing `mcp_edge`/labels, and the smoke exits with `resolved MCP service has no Traefik labels`.

- [ ] **Step 6: Implement the exact production edge**

In `docker-compose.yml`:

1. Pin the Traefik image to `traefik:v3.7.3`, then add these command arguments after `--entryPoints.web.address=:80`:

```yaml
      - "--entryPoints.web.transport.respondingTimeouts.readTimeout=60s"
      - "--accesslog=true"
      - "--accesslog.format=json"
      - "--accesslog.fields.headers.defaultmode=drop"
      - "--accesslog.fields.queryparameters.defaultmode=drop"
      - "--accesslog.fields.names.ClientAddr=drop"
      - "--accesslog.fields.names.ClientHost=drop"
      - "--entryPoints.web.observability.accessLogs=false"
      - "--entryPoints.traefik.address=:8080"
      - "--entryPoints.traefik.observability.accessLogs=false"
```

2. Add `mcp_edge` to the Traefik service networks.
3. Set production `MCP_ALLOWED_ORIGINS=${MCP_ALLOWED_ORIGINS:-https://sysndd.dbmr.unibe.ch}` and let the development override add exact localhost origins, replace the MCP service network comment/block, and add these labels:

```yaml
    networks:
      # Public ingress arrives only through the dedicated internal edge network;
      # MCP keeps its internal DB path and receives no internet egress.
      - mcp_edge
      - backend
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=sysndd_mcp_edge"
      - "traefik.http.routers.mcp-post.rule=Host(`sysndd.dbmr.unibe.ch`) && Path(`/mcp`) && Method(`POST`)"
      - "traefik.http.routers.mcp-post.entrypoints=web"
      - "traefik.http.routers.mcp-post.priority=200"
      - "traefik.http.routers.mcp-post.service=mcp"
      - "traefik.http.routers.mcp-post.middlewares=mcp-shared-rate,mcp-post-body,mcp-post-inflight,mcp-strip"
      - "traefik.http.routers.mcp-post.observability.accesslogs=true"
      - "traefik.http.routers.mcp-get.rule=Host(`sysndd.dbmr.unibe.ch`) && Path(`/mcp`) && Method(`GET`) && HeaderRegexp(`Accept`, `(?i)(^|[[:space:],])text/event-stream([[:space:];,]|$)`)"
      - "traefik.http.routers.mcp-get.entrypoints=web"
      - "traefik.http.routers.mcp-get.priority=200"
      - "traefik.http.routers.mcp-get.service=mcp"
      - "traefik.http.routers.mcp-get.middlewares=mcp-shared-rate,mcp-strip"
      - "traefik.http.routers.mcp-get.observability.accesslogs=true"
      - "traefik.http.middlewares.mcp-shared-rate.ratelimit.average=120"
      - "traefik.http.middlewares.mcp-shared-rate.ratelimit.period=1m"
      - "traefik.http.middlewares.mcp-shared-rate.ratelimit.burst=20"
      - "traefik.http.middlewares.mcp-shared-rate.ratelimit.sourcecriterion.requesthost=true"
      - "traefik.http.middlewares.mcp-post-body.buffering.maxrequestbodybytes=262144"
      - "traefik.http.middlewares.mcp-post-inflight.inflightreq.amount=4"
      - "traefik.http.middlewares.mcp-post-inflight.inflightreq.sourcecriterion.requesthost=true"
      - "traefik.http.middlewares.mcp-strip.stripprefix.prefixes=/mcp"
      - "traefik.http.services.mcp.loadbalancer.server.port=8787"
```

4. Add the top-level network:

```yaml
  mcp_edge:
    name: sysndd_mcp_edge
    driver: bridge
    internal: true
```

- [ ] **Step 7: Run exact and live checks and verify GREEN**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-select-principal-compose.R')"
docker compose -f docker-compose.yml --env-file .env.example --profile mcp config --quiet
make test-mcp-edge
```

Expected: testthat passes, Compose resolution exits 0, and the smoke reports enabled routers plus browser/POST/405/413/429 PASS.

- [ ] **Step 8: Commit the edge contract**

```bash
git add api/tests/testthat/test-mcp-select-principal-compose.R scripts/tests/test-mcp-traefik-edge.sh Makefile docker-compose.yml
git commit -m "fix(629): expose bounded public MCP transport"
```

### Task 2: Correct the Public MCP Information Page

**Files:**
- Modify: `app/src/views/help/McpInfoView.spec.ts`
- Modify: `app/src/views/help/McpInfoView.vue`
- Modify: `app/tests/e2e/mcp-info.spec.ts`

**Interfaces:**
- Consumes: `window.location.origin` and the existing public-page component structure.
- Produces: credential-free setup guidance without asserting volatile product-specific auth labels.

- [ ] **Step 1: Replace the stale Vitest contract before editing the page**

Replace the first test in `McpInfoView.spec.ts` with:

```ts
it('documents the credential-free public MCP transport and shared fair-use behavior', () => {
  const wrapper = mount(McpInfoView, {
    global: {
      stubs: bootstrapStubs,
    },
  });

  const text = wrapper.text().replace(/\s+/g, ' ');
  expect(wrapper.find('.public-page').exists()).toBe(true);
  expect(wrapper.find('.public-shell').exists()).toBe(true);
  expect(wrapper.find('.public-hero').exists()).toBe(true);
  expect(wrapper.find('.public-panel').exists()).toBe(true);
  expect(text).toContain('SysNDD MCP');
  expect(text).toContain('Read-only');
  expect(text).toContain(`${window.location.origin}/mcp`);
  expect(text).toContain('No SysNDD account, API key, or access token is required');
  expect(text).toContain('leave authentication unset');
  expect(text).toContain('shared capacity');
  expect(text).toContain('HTTP 429');
  expect(text).toContain('retry with backoff');
  expect(text).toContain('cache stable results');
  expect(text).toContain('Standalone SSE listening is not currently offered');
  expect(text).not.toMatch(
    /access-protected|protected URL|token-protected|Bearer|access token your operator|then authenticate|pick the auth method/i
  );
});
```

- [ ] **Step 2: Update the focused Playwright expectation before editing the page**

Change the browser-page assertion at `app/tests/e2e/mcp-info.spec.ts:8` to:

```ts
await expect(
  page.getByText('No SysNDD account, API key, or access token is required')
).toBeVisible();
```

Replace the protocol-test comment with:

```ts
// The standard Playwright stack does not enable the opt-in `mcp` profile.
// When MCP is absent, POST /mcp reaches the SPA service and this protocol-only
// assertion is environment-gated. The browser test above always verifies the
// public information contract; scripts/tests/test-mcp-traefik-edge.sh verifies
// the production router labels against a disposable Traefik instance.
```

- [ ] **Step 3: Run Vitest and verify RED**

Run:

```bash
cd app && npx vitest run src/views/help/McpInfoView.spec.ts
```

Expected: FAIL because protected/token copy remains and public/fair-use/SSE-limit copy is absent.

- [ ] **Step 4: Replace protected-endpoint copy with the public contract**

Make these template changes in `McpInfoView.vue`:

1. Replace the info notice with:

```html
This information page shares its URL with the public MCP transport. Browser navigation renders
this page; MCP clients send protocol requests to the same URL. No SysNDD account, API key, or
access token is required.
```

2. Change `How to connect` copy to `Point your client at the public SysNDD MCP server.`
3. Change the Transport value to `Streamable HTTP (JSON-RPC over POST)`.
4. Replace its muted paragraph with:

```html
<p class="mcp-muted">
  The production endpoint is public and credential-free. Leave authentication unset; if your
  client requires a choice, use its unauthenticated or no-auth option.
</p>
```

5. Replace the coding-client introduction with:

```html
<p>
  These clients connect from your own machine. Use the URL as shown and do not add an
  <code>Authorization</code> header.
</p>
```

6. Replace the Claude Code note with `No account, API key, or bearer token is required.`
7. Replace the browser-chatbot introduction with:

```html
<p>
  Web chatbots connect from the vendor's servers. Use the public HTTPS endpoint above and leave
  authentication unset. Availability depends on each client's support for custom remote MCP
  servers.
</p>
```

8. Change each Claude/ChatGPT connector auth step to product-neutral wording: `Paste the HTTPS MCP server URL above and leave authentication unset.`
9. Insert immediately before `Safety & protocol notes`:

```html
<article class="mcp-section">
  <h2>Fair use &amp; availability</h2>
  <p>
    The public service has shared capacity. If a client receives HTTP 429, retry with backoff
    instead of immediately repeating the request.
  </p>
  <p>
    Prefer compact, focused calls and cache stable results so the shared research service remains
    responsive. Standalone SSE listening is not currently offered.
  </p>
</article>
```

- [ ] **Step 5: Run focused frontend checks and verify GREEN**

Run:

```bash
cd app && npx vitest run src/views/help/McpInfoView.spec.ts
cd app && npx eslint src/views/help/McpInfoView.vue src/views/help/McpInfoView.spec.ts app/tests/e2e/mcp-info.spec.ts
cd app && npx prettier --check src/views/help/McpInfoView.vue src/views/help/McpInfoView.spec.ts app/tests/e2e/mcp-info.spec.ts
```

Expected: both Vitest tests pass; ESLint and Prettier exit 0.

- [ ] **Step 6: Commit the information-page correction**

```bash
git add app/src/views/help/McpInfoView.vue app/src/views/help/McpInfoView.spec.ts app/tests/e2e/mcp-info.spec.ts
git commit -m "fix(629): document credential-free MCP access"
```

### Task 3: Align Canonical Policy and Operator Documentation

**Files:**
- Modify: `api/tests/testthat/test-mcp-select-principal-compose.R`
- Modify: `AGENTS.md`
- Modify: `docker-compose.override.yml`
- Modify: `documentation/03-api.qmd`
- Modify: `documentation/09-deployment.qmd`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: the exact values and topology established in Task 1.
- Produces: one consistent public/no-auth reachability contract across persistent repository guidance.

- [ ] **Step 1: Add scoped documentation-test helpers**

Append to the R test file:

```r
.mcp_markdown_section <- function(path, heading, next_heading_pattern) {
  lines <- readLines(path, warn = FALSE)
  start <- grep(paste0("^", heading, "$"), lines)
  stopifnot(length(start) == 1L)
  later <- grep(next_heading_pattern, lines)
  later <- later[later > start]
  end <- if (length(later)) min(later) - 1L else length(lines)
  paste(lines[start:end], collapse = "\n")
}
```

- [ ] **Step 2: Add the failing scoped policy/documentation contract**

Append:

```r
test_that("public MCP policy and documentation match the Compose edge", {
  api_section <- .mcp_markdown_section(
    file.path(.mcp_compose_repo_root, "documentation", "03-api.qmd"),
    "## Read-only MCP sidecar",
    "^## "
  )
  deployment_section <- .mcp_markdown_section(
    file.path(.mcp_compose_repo_root, "documentation", "09-deployment.qmd"),
    "### MCP sidecar settings",
    "^#{2,3} "
  )
  agents_section <- .mcp_markdown_section(
    file.path(.mcp_compose_repo_root, "AGENTS.md"),
    "### Read-only MCP sidecar",
    "^### "
  )
  changelog <- .mcp_markdown_section(
    file.path(.mcp_compose_repo_root, "CHANGELOG.md"),
    "## \\[Unreleased\\]",
    "^## \\["
  )
  override <- paste(readLines(file.path(
    .mcp_compose_repo_root, "docker-compose.override.yml"
  ), warn = FALSE), collapse = "\n")

  for (section in list(api_section, deployment_section, agents_section)) {
    expect_match(section, "public and credential-free", fixed = TRUE)
    expect_match(section, "approved-public", fixed = TRUE)
    expect_false(grepl(
      "private/internal by default|Do not expose public unauthenticated|static-bearer|mcp-auth|protected access",
      section,
      ignore.case = TRUE
    ))
  }

  expect_match(api_section, "shared 120-request-per-minute", fixed = TRUE)
  expect_match(api_section, "256 KiB", fixed = TRUE)
  expect_match(api_section, "HTTP 429", fixed = TRUE)
  expect_match(deployment_section, "sysndd_mcp_edge", fixed = TRUE)
  expect_match(deployment_section, "60-second", fixed = TRUE)
  expect_match(deployment_section, "ClientAddr", fixed = TRUE)
  expect_match(deployment_section, "ClientHost", fixed = TRUE)
  expect_match(agents_section, "MCP-compliant OAuth", fixed = TRUE)
  expect_match(override, "dedicated internal edge network", fixed = TRUE)
  expect_match(changelog, "#629", fixed = TRUE)
  expect_match(changelog, "credential-free", fixed = TRUE)
})
```

- [ ] **Step 3: Run the documentation contract and verify RED**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-select-principal-compose.R')"
```

Expected: FAIL on the old protected/internal policy and absent edge-control text.

- [ ] **Step 4: Update canonical `AGENTS.md` policy**

Replace lines 245-247 with:

```markdown
MCP v1 is intentionally public and credential-free when the opt-in production Compose `mcp` profile is enabled. Keep public no-auth reachability coupled to the approved-public, read-only contract: private, user-specific, or write-capable tools require MCP-compliant OAuth before exposure. Public ingress must use the dedicated internal `mcp_edge` network so the sidecar retains no internet egress, plus the source-controlled shared rate, POST concurrency/body, read-time, and MCP-only access-log controls.

The frontend owns a public `/mcp` information page for ordinary browser `GET` requests. Production routes exact `POST /mcp` and `GET /mcp` with `Accept: text/event-stream` to the sidecar; the latter currently returns the protocol-permitted 405 because standalone SSE listening is not offered. Keep routing method/header-scoped so normal browser visits render the information page. The MCP transport retains Origin validation, but Origin is not authentication: absent Origin is accepted for server clients and untrusted browser origins are rejected.
```

- [ ] **Step 5: Correct the development override comment**

Replace `docker-compose.override.yml:77-81` with:

```yaml
  # Local MCP also publishes a loopback-only port for direct developer probes.
  # Production ingress uses the dedicated internal edge network from the base
  # Compose file; this dev-only proxy attachment supplies local host reachability.
```

Keep the existing `mcp` service, networks, port, and environment values below the comment unchanged.

- [ ] **Step 6: Rewrite the API reachability paragraph**

Replace `documentation/03-api.qmd:41` with:

```markdown
MCP v1 is intentionally public and credential-free when the opt-in production Compose `mcp` profile is enabled. The same exact `https://sysndd.dbmr.unibe.ch/mcp` URL serves two request shapes: ordinary browser `GET` navigation renders the informational Vue page, while JSON-RPC `POST` and `GET` requests accepting `text/event-stream` are routed to the `mcptools` transport with `/mcp` stripped. No SysNDD account, API key, or access token is required. The current stateless transport returns the protocol-permitted 405 for the GET shape because standalone SSE listening is not offered. Development Vite preserves the browser/protocol split.

The edge uses a shared 120-request-per-minute bucket for the production Host (burst 20), permits four complete POST requests in flight, rejects request bodies larger than 256 KiB, and applies a 60-second whole-request read timeout. A limited client receives HTTP 429 and should retry with backoff. MCP reaches Traefik only over the internal `sysndd_mcp_edge` network and retains no internet egress. These availability controls complement, rather than replace, the SELECT-only approved-public data boundary.
```

- [ ] **Step 7: Replace the protected deployment overlay**

In `documentation/09-deployment.qmd`, replace the paragraph beginning `The production Compose file keeps MCP internal-only` through the `mcp-auth` instruction with:

```markdown
The production Compose `mcp` profile intentionally exposes the read-only transport at `https://sysndd.dbmr.unibe.ch/mcp`; ordinary `docker compose up` still excludes the profile. The route is public and credential-free. No SysNDD account, API key, or bearer token is required.

Traefik and MCP share only the internal `sysndd_mcp_edge` network; MCP separately retains its internal `backend` database path and is not attached to the egress-capable `proxy` network. Exact JSON-RPC `POST /mcp` and `GET /mcp` requests accepting `text/event-stream` outrank the app route and strip `/mcp`. Both routers explicitly bind the MCP service. Ordinary browser GET remains on the priority-1 app route. The pinned stateless transport returns 405 for the GET protocol shape because standalone SSE listening is not currently offered; DELETE sessions, direct-browser CORS, `/mcp/`, and arbitrary bearer headers are not part of v1.

The source-controlled edge policy is shared across all callers to the one production Host: 120 requests per minute with burst 20; four fully received POST requests in flight; 256 KiB maximum POST body; and a 60-second whole-request read timeout. POST middleware order is shared rate, body limit, in-flight work cap, then path stripping. Rate or concurrency rejection returns HTTP 429; callers should back off and cache stable results. The shared Host bucket is deliberate: it remains trustworthy behind the institutional TLS proxy without accepting spoofable forwarding headers and also bounds distributed-source abuse. A horizontally scaled Traefik deployment needs the distributed Redis limiter or an explicit per-instance-limit decision.

Traefik enables JSON access logging only for the two MCP routers: the shared web and internal API/ping entrypoints opt out, while headers, query parameters, request bodies, `ClientAddr`, and `ClientHost` are dropped. Existing Docker log rotation bounds retention. Use those privacy-bounded MCP-only logs for response status, request duration, and 403/405/413/429 volume. The live smoke proves the router scope and sentinel omission against the resolved production command.

No-auth public access is valid only while every tool exposes approved-public research data, remains read-only, and makes no user-specific authorization decision. Origin validation is retained for browser-origin/DNS-rebinding protection, not as authentication: server clients without Origin are accepted and untrusted Origins are rejected. Private, user-specific, or write-capable tools require MCP-compliant OAuth before exposure.
```

- [ ] **Step 8: Update Operations Notes**

Replace the bullet beginning `Keep the MCP service on internal/private access` with:

```markdown
- Keep public MCP credential-free only while every tool remains approved-public and read-only. Preserve the dedicated internal ingress network, no-egress sidecar topology, shared rate, POST work/body, read-time, and MCP-only logging controls. MCP tools and prompts must not call Gemini/LLM generation, live external providers, raw SQL/R execution, write routes, admin/user/log/job routes, draft reviews, or re-review data. Analysis tools may read only validated stored summary projections and remain bounded by compact defaults plus `max_response_chars`. Private, user-specific, or write-capable tools require MCP-compliant OAuth before exposure.
```

- [ ] **Step 9: Add the Unreleased changelog entry**

Insert beneath `## [Unreleased]`:

```markdown
### Changed

- **The opt-in MCP endpoint is now explicitly public and credential-free** (#629).
  Compose, canonical policy, deployment documentation, and the `/mcp` information page now
  match the production contract instead of requesting a bearer token that does not exist.
  Traefik uses an internal ingress-only network, a shared 120-request-per-minute bucket
  (burst 20), four in-flight POST requests, 256 KiB bodies, a 60-second read timeout, and
  MCP-only privacy-bounded access logs. The sidecar retains no internet egress and the
  SELECT-only approved-public projection boundary is unchanged.
```

- [ ] **Step 10: Run the scoped contract and verify GREEN**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-select-principal-compose.R')"
```

Expected: all Compose and documentation assertions pass with zero failures.

- [ ] **Step 11: Commit policy/documentation alignment**

```bash
git add api/tests/testthat/test-mcp-select-principal-compose.R AGENTS.md docker-compose.override.yml documentation/03-api.qmd documentation/09-deployment.qmd CHANGELOG.md
git commit -m "docs(629): align public MCP deployment policy"
```

### Task 4: Verify, Audit, and Review the Completed Change

**Files:**
- Review: all files changed from `master`

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: current evidence for completion and a review-ready branch.

- [ ] **Step 1: Run targeted behavior and configuration checks**

```bash
cd app && npx vitest run src/views/help/McpInfoView.spec.ts
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-mcp-select-principal-compose.R')"
docker compose -f docker-compose.yml --env-file .env.example --profile mcp config --quiet
make test-mcp-edge
```

Expected: two frontend tests pass; testthat passes; Compose resolves; the disposable Traefik smoke proves enabled routers and browser/POST/405/413/429 behavior.

- [ ] **Step 2: Run frontend quality checks**

```bash
cd app && npx eslint src/views/help/McpInfoView.vue src/views/help/McpInfoView.spec.ts app/tests/e2e/mcp-info.spec.ts
cd app && npx prettier --check src/views/help/McpInfoView.vue src/views/help/McpInfoView.spec.ts app/tests/e2e/mcp-info.spec.ts
cd app && npm run type-check
cd app && npm run type-check:strict
```

Expected: every command exits 0.

- [ ] **Step 3: Run repository quality and API gates**

```bash
make code-quality-audit
make lint-api
git diff --check master...HEAD
make pre-commit
```

Expected: every command exits 0. Record exact infrastructure-gated skips; do not report them as passes.

- [ ] **Step 4: Perform the focused security/maintainability review**

Inspect `git diff master...HEAD` and confirm:

```text
- Only exact POST and SSE-shaped GET requests outrank the browser app route.
- Both routers explicitly bind service mcp and Traefik reports them enabled.
- No auth middleware, credential, raw SQL/R, write route, external call, or private source was added.
- MCP joins only backend and mcp_edge; both are internal, so sidecar egress remains absent.
- The shared limiter explicitly keys on request Host; no XFF trust was introduced.
- Only complete POST requests occupy the four-request R-work cap.
- Bodies, headers, query parameters, `ClientAddr`, and `ClientHost` are absent from MCP access logs; app/internal router requests are not access-logged.
- AGENTS, Compose comments, UI, API docs, deployment docs, tests, and changelog agree.
- Existing SELECT-only principal and approved-public projection tests remain green.
```

- [ ] **Step 5: Audit completion against issue #629**

Map issue requirements to evidence:

```text
Open by design                    -> base Compose public no-auth routers and canonical policy
Drop bearer-token instructions    -> normalized positive/negative Vitest and scoped docs assertions
Rate limiting / abuse handling    -> shared-rate/body/work/read controls plus isolated 413/429 smoke
Browser information page retained -> exact method/header routers plus browser-route smoke
Read-only guarantees preserved    -> no-egress internal network and unchanged MCP/principal code
Community standards               -> optional-auth rationale, Origin handling, 405, backoff, observability
```

- [ ] **Step 6: Apply any review correction through a fresh red-green cycle**

For each defect found, first add or tighten the smallest relevant assertion in one of these exact tests, run it to observe failure, implement the correction, and rerun it:

```text
Compose/routing/control defect -> api/tests/testthat/test-mcp-select-principal-compose.R or scripts/tests/test-mcp-traefik-edge.sh
Information-page defect        -> app/src/views/help/McpInfoView.spec.ts
Persistent-policy defect       -> scoped documentation contract in test-mcp-select-principal-compose.R
```

Commit only if a correction was necessary; do not create an empty commit.
