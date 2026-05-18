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
            Read-only Model Context Protocol access for approved public SysNDD gene, entity,
            publication, and phenotype evidence.
          </p>
        </div>
      </header>

      <BAlert variant="info" show class="mcp-notice">
        <i class="bi bi-info-circle me-2" aria-hidden="true" />
        This page explains the SysNDD MCP service. It is not the public MCP transport endpoint. The
        live transport is kept private or protected and is intended for MCP clients, not normal
        browser navigation.
      </BAlert>

      <section class="public-panel mcp-grid" aria-label="MCP overview">
        <article class="mcp-section">
          <h2>What it provides</h2>
          <p>
            Read-only MCP tools for approved SysNDD gene, entity, phenotype, and publication
            evidence.
          </p>
          <ul class="mcp-list">
            <li>Public approved data only</li>
            <li>No drafts, admin data, code execution, external calls, or writes</li>
            <li>Stable JSON responses with schema version metadata</li>
          </ul>
        </article>

        <article class="mcp-section">
          <h2>How to connect</h2>
          <p>SysNDD displays the MCP URL for the current configured public server.</p>
          <dl class="mcp-definition-list">
            <div>
              <dt>Configured MCP URL</dt>
              <dd>
                <code>{{ mcpUrl }}</code>
              </dd>
            </div>
          </dl>
        </article>

        <article class="mcp-section mcp-section--wide">
          <h2>Client configuration example</h2>
          <pre class="mcp-code"><code>{
  "mcpServers": {
    "sysndd": {
      "type": "http",
      "url": "{{ mcpUrl }}"
    }
  }
}</code></pre>
          <p class="mcp-muted">
            The endpoint is deployment-configured. In production, use the protected route supplied
            by the deployment operator.
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
        </article>

        <article class="mcp-section">
          <h2>Protocol notes</h2>
          <p>
            MCP Streamable HTTP uses JSON-RPC over POST and optional SSE over GET. A plain browser
            visit to a real MCP endpoint is therefore not expected to render a website.
          </p>
          <p>
            See the
            <BLink
              href="https://modelcontextprotocol.io/specification/2025-11-25/basic/transports"
              target="_blank"
            >
              MCP transport specification
            </BLink>
            for client transport behavior.
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

.mcp-muted {
  margin-bottom: 0;
  color: #667085;
}

@media (max-width: 767.98px) {
  .mcp-grid {
    grid-template-columns: 1fr;
  }
}
</style>
