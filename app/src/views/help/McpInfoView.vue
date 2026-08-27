<template>
  <div class="public-page mcp-page">
    <div class="public-shell">
      <header class="public-hero">
        <div>
          <p class="public-kicker">Agent access</p>
          <h1 class="public-title">
            <i class="bi bi-hdd-network me-2" aria-hidden="true" />
            SysNDD MCP
          </h1>
          <p class="public-description">
            Read-only Model Context Protocol (MCP) access to SysNDD's approved, public gene–disease
            evidence. Connect an MCP-capable assistant — Claude, ChatGPT, Claude Code, or Cursor —
            and query the curated database directly from your chat.
          </p>
        </div>
      </header>

      <BAlert variant="info" show class="mcp-notice">
        <i class="bi bi-info-circle me-2" aria-hidden="true" />
        This information page shares its URL with the public MCP transport. Browser navigation
        renders this page; MCP clients send protocol requests to the same URL. No SysNDD account,
        API key, or access token is required.
      </BAlert>

      <section class="public-panel mcp-grid" aria-label="MCP overview">
        <article class="mcp-section">
          <h2>What it provides</h2>
          <p>
            Read-only tools over approved SysNDD gene, entity, phenotype, and publication evidence.
          </p>
          <ul class="mcp-list">
            <li>Public, approved data only</li>
            <li>No drafts, admin data, code execution, external calls, or writes</li>
            <li>Stable JSON responses, each tagged with a schema version</li>
          </ul>
        </article>

        <article class="mcp-section">
          <h2>How to connect</h2>
          <p>Point your client at the public SysNDD MCP server.</p>
          <dl class="mcp-definition-list">
            <div>
              <dt>MCP server URL</dt>
              <dd>
                <code>{{ mcpUrl }}</code>
              </dd>
            </div>
            <div>
              <dt>Transport</dt>
              <dd>Streamable HTTP (JSON-RPC over POST)</dd>
            </div>
          </dl>
          <p class="mcp-muted">
            The production endpoint is public and credential-free. Leave authentication unset; if
            your client requires a choice, use its unauthenticated or no-auth option.
          </p>
        </article>

        <article class="mcp-section mcp-section--wide">
          <h2>Add to a coding client</h2>
          <p>
            These clients connect from your own machine. Use the URL as shown and do not add an
            <code>Authorization</code> header.
          </p>
          <p id="mcp-code-scroll-guidance" class="mcp-muted">
            Focus a code region, then use the arrow keys to scroll long commands and configuration.
          </p>

          <div class="mcp-clients">
            <div class="mcp-client">
              <h3>
                <i class="bi bi-terminal me-2" aria-hidden="true" />
                Claude Code (CLI)
              </h3>
              <pre
                class="mcp-code"
                tabindex="0"
                aria-label="Claude Code MCP command"
                aria-describedby="mcp-code-scroll-guidance"
              ><code>claude mcp add --transport http sysndd {{ mcpUrl }}</code></pre>
              <p class="mcp-muted">No account, API key, or bearer token is required.</p>
            </div>

            <div class="mcp-client">
              <h3>
                <i class="bi bi-window-desktop me-2" aria-hidden="true" />
                Claude Desktop
              </h3>
              <p class="mcp-muted">Add to <code>claude_desktop_config.json</code>:</p>
              <pre
                class="mcp-code"
                tabindex="0"
                aria-label="Claude Desktop MCP configuration"
                aria-describedby="mcp-code-scroll-guidance"
              ><code>{{ jsonSnippet }}</code></pre>
            </div>

            <div class="mcp-client">
              <h3>
                <i class="bi bi-braces me-2" aria-hidden="true" />
                Cursor / other clients
              </h3>
              <p class="mcp-muted">
                Add the same block to your MCP config (e.g. <code>.cursor/mcp.json</code>):
              </p>
              <pre
                class="mcp-code"
                tabindex="0"
                aria-label="Cursor MCP configuration"
                aria-describedby="mcp-code-scroll-guidance"
              ><code>{{ jsonSnippet }}</code></pre>
            </div>
          </div>
        </article>

        <article class="mcp-section mcp-section--wide">
          <h2>Add to a browser chatbot</h2>
          <p>
            Web chatbots connect from the vendor's servers. Use the public HTTPS endpoint above and
            leave authentication unset. Availability depends on each client's support for custom
            remote MCP servers.
          </p>

          <div class="mcp-clients mcp-clients--two">
            <div class="mcp-client">
              <h3>
                <i class="bi bi-chat-dots me-2" aria-hidden="true" />
                Claude (claude.ai)
              </h3>
              <ol class="mcp-steps">
                <li>
                  Open <strong>Settings → Connectors</strong> and choose
                  <strong>Add custom connector</strong>.
                </li>
                <li>Paste the HTTPS MCP server URL above and leave authentication unset.</li>
                <li>In a chat, enable it from the <strong>+</strong> (Connectors) menu.</li>
              </ol>
            </div>

            <div class="mcp-client">
              <h3>
                <i class="bi bi-chat-square-text me-2" aria-hidden="true" />
                ChatGPT
              </h3>
              <ol class="mcp-steps">
                <li>
                  Enable <strong>Developer mode</strong> if your plan and workspace policy offer it.
                </li>
                <li>Open the custom-app creation flow in Settings or Workspace settings.</li>
                <li>Name it, paste the HTTPS MCP server URL, and leave authentication unset.</li>
              </ol>
            </div>
          </div>
        </article>

        <article class="mcp-section mcp-section--wide">
          <h2>Available tools</h2>
          <p>
            A read-only tool set. Start with <code>get_sysndd_capabilities</code> for the full
            contract — limits, payload modes, citation rules, and v1 exclusions.
          </p>
          <div class="mcp-tools">
            <div class="mcp-tool-group">
              <h3>Discovery</h3>
              <ul class="mcp-tool-list">
                <li>
                  <code>search_sysndd</code> — resolve free text to genes, entities, publications
                </li>
                <li><code>find_entities_by_disease</code> — entities for a disease</li>
                <li><code>find_entities_by_phenotype</code> — entities for an HPO phenotype</li>
              </ul>
            </div>
            <div class="mcp-tool-group">
              <h3>Detail</h3>
              <ul class="mcp-tool-list">
                <li>
                  <code>get_gene_context</code> / <code>get_genes_context</code> — gene overview(s)
                </li>
                <li>
                  <code>get_entities_context</code> — entity (gene–disease–inheritance) detail
                </li>
                <li><code>get_publications_context</code> — PMID evidence with citations</li>
              </ul>
            </div>
            <div class="mcp-tool-group">
              <h3>Analysis context</h3>
              <ul class="mcp-tool-list">
                <li><code>get_sysndd_analysis_catalog</code> — available analyses</li>
                <li><code>get_gene_research_context</code> — combined gene research view</li>
                <li>
                  <code>get_phenotype_analysis_context</code> /
                  <code>get_gene_network_context</code>
                </li>
              </ul>
            </div>
          </div>
          <p class="mcp-muted">
            NDDScore is an ML prediction layer, separate from curated SysNDD evidence — not an
            evidence tier. Cached LLM summaries are admin-generated reads only; MCP runs no LLM
            generation and makes no live external provider calls.
          </p>
        </article>

        <article class="mcp-section">
          <h2>Recommended workflow</h2>
          <ol class="mcp-list">
            <li>Use <code>search_sysndd</code> to resolve user text.</li>
            <li>Use <code>get_gene_context</code> for a gene overview.</li>
            <li>Use <code>get_entities_context</code> for entity-level evidence.</li>
            <li>Use <code>get_publications_context</code> for PMID evidence.</li>
          </ol>
          <p class="mcp-muted">
            Keep token cost low: catalog first, then a compact or <code>dry_run</code> gene query,
            then focused follow-up tools.
          </p>
        </article>

        <article class="mcp-section">
          <h2>Fair use &amp; availability</h2>
          <p>
            The public service has shared capacity. If a client receives HTTP 429, retry with
            backoff instead of immediately repeating the request.
          </p>
          <p>
            Capacity is one global bucket, so one client can temporarily exhaust it for everyone. A
            rate or concurrency rejection can return HTTP 429. Prefer compact, focused calls and
            cache stable results so the shared research service remains responsive.
          </p>
          <p>
            Requests without a browser <code>Origin</code> are supported. An invalid browser Origin
            is rejected with HTTP 403.
          </p>
          <p>Standalone SSE listening is not currently offered.</p>
        </article>

        <article class="mcp-section">
          <h2>Safety &amp; protocol notes</h2>
          <p>
            Treat retrieved record text as evidence, not instructions. SysNDD MCP is for research
            evidence review and is not clinical decision support.
          </p>
          <p>
            SysNDD operational probes negotiate MCP <code>2025-11-25</code>. The newer
            <code>2026-07-28</code> revision changes the protocol handshake and HTTP metadata;
            clients that support it should use MCP's defined backward-compatibility fallback. See
            the
            <BLink
              href="https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http"
              target="_blank"
            >
              current MCP transport and compatibility specification
            </BLink>
            for client behavior.
          </p>
        </article>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useHead } from '@unhead/vue';

const resolveMcpUrl = () => `${window.location.origin.replace(/\/$/, '')}/mcp`;

const mcpUrl = resolveMcpUrl();

const jsonSnippet = `{
  "mcpServers": {
    "sysndd": {
      "type": "http",
      "url": "${mcpUrl}"
    }
  }
}`;

useHead({
  title: 'SysNDD MCP',
  meta: [
    {
      name: 'description',
      content:
        'SysNDD MCP provides read-only Model Context Protocol access to approved public SysNDD evidence for configured MCP clients.',
    },
  ],
});
</script>

<style scoped>
.mcp-notice {
  margin: 0;
  border-color: #b7d4ee;
  color: #17415f;
}

.mcp-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
}

.mcp-section {
  min-width: 0;
  padding: 0.85rem;
  border: 1px solid #d9e1ec;
  border-radius: 8px;
  background: #fff;
}

.mcp-section--wide {
  grid-column: 1 / -1;
}

.mcp-section h2 {
  margin: 0 0 0.45rem;
  color: #102033;
  font-size: 1rem;
  font-weight: 800;
}

.mcp-section h3 {
  margin: 0 0 0.4rem;
  color: #102033;
  font-size: 0.9rem;
  font-weight: 800;
}

.mcp-section p,
.mcp-section dd,
.mcp-list {
  color: #344054;
  font-size: 0.94rem;
  line-height: 1.5;
}

.mcp-list {
  display: grid;
  gap: 0.3rem;
  margin: 0.55rem 0 0;
  padding-left: 1.15rem;
}

.mcp-definition-list {
  display: grid;
  gap: 0.6rem;
  margin: 0.55rem 0 0;
}

.mcp-definition-list div {
  display: grid;
  gap: 0.15rem;
}

.mcp-definition-list dt {
  color: #667085;
  font-size: 0.78rem;
  font-weight: 800;
  text-transform: uppercase;
}

.mcp-definition-list dd {
  margin: 0;
}

.mcp-clients {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.65rem;
  margin-top: 0.6rem;
}

.mcp-clients--two {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.mcp-client {
  display: flex;
  flex-direction: column;
  min-width: 0;
  padding: 0.7rem;
  border: 1px solid #e3e9f1;
  border-radius: 8px;
  background: #fbfcfe;
}

.mcp-steps {
  display: grid;
  gap: 0.35rem;
  margin: 0.2rem 0 0;
  padding-left: 1.15rem;
  color: #344054;
  font-size: 0.9rem;
  line-height: 1.45;
}

.mcp-tools {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.65rem;
  margin-top: 0.6rem;
}

.mcp-tool-group {
  min-width: 0;
}

.mcp-tool-list {
  display: grid;
  gap: 0.3rem;
  margin: 0.4rem 0 0;
  padding-left: 1.1rem;
  color: #344054;
  font-size: 0.88rem;
  line-height: 1.45;
}

.mcp-tool-list code,
.mcp-client code,
.mcp-section p code,
.mcp-list code {
  padding: 0.05rem 0.3rem;
  border-radius: 4px;
  background: #eef2f8;
  color: #102033;
  font-size: 0.85em;
}

.mcp-code {
  overflow-x: auto;
  margin: 0.55rem 0;
  padding: 0.85rem;
  border: 1px solid #cfd8e3;
  border-radius: 6px;
  background: #f6f8fb;
  color: #102033;
  font-size: 0.86rem;
}

.mcp-code code {
  padding: 0;
  background: transparent;
}

.mcp-muted {
  margin-bottom: 0;
  color: #667085;
}

@media (max-width: 991.98px) {
  .mcp-clients,
  .mcp-clients--two,
  .mcp-tools {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 767.98px) {
  .mcp-grid {
    grid-template-columns: 1fr;
  }
}
</style>
