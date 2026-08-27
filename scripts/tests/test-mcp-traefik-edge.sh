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

for required_command in docker jq curl; do
  command -v "${required_command}" >/dev/null || {
    echo "[mcp-edge] missing required command: ${required_command}" >&2
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
            body = b'{"jsonrpc":"2.0","id":1,"result":{"server":"MCP-STUB"}}'
            self.reply(200, body, "application/json")
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
  traefik:v3.7 \
  --providers.docker=true \
  --providers.docker.exposedbydefault=false \
  --providers.docker.network="${NETWORK}" \
  --providers.docker.constraints="Label(\`sysndd.mcp-edge-smoke\`, \`${SUFFIX}\`)" \
  --entrypoints.web.address=:80 \
  --api=true --api.insecure=true --log.level=ERROR >/dev/null

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
  -H 'Host: sysndd.dbmr.unibe.ch' -H 'Accept: text/event-stream' "${BASE}/mcp")"
[[ "${GET_STATUS}" == "405" ]]

BODY_STATUS="$(head -c 300000 /dev/zero | tr '\0' x | curl -sS -o /dev/null \
  -w '%{http_code}' -H 'Host: sysndd.dbmr.unibe.ch' \
  -H 'Content-Type: application/json' -X POST --data-binary @- "${BASE}/mcp")"
[[ "${BODY_STATUS}" == "413" ]]

RATE_LIMITED=0
for _ in $(seq 1 30); do
  status="$(curl -sS -o /dev/null -w '%{http_code}' \
    -H 'Host: sysndd.dbmr.unibe.ch' -H 'Content-Type: application/json' \
    -X POST --data '{}' "${BASE}/mcp")"
  [[ "${status}" == "429" ]] && RATE_LIMITED=1
done
[[ "${RATE_LIMITED}" == "1" ]]

echo "[mcp-edge] PASS: routers enabled; browser, POST, GET 405, body 413, and rate 429 verified"
