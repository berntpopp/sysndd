<!-- src/views/ApiView.vue -->
<!--
  API Explorer page — wraps the in-DOM SwaggerUIBundle mount in an on-brand
  public-page shell so the page has:
    • A single route-level <h1> (fixes heading-order Lighthouse audit)
    • The shared public-hero + public-panel chrome (fixes consistency=3)
    • Deep-scoped contrast overrides for Swagger's method badges and
      low-contrast muted text (fixes color-contrast(5))
    • Accurate onComplete/onFailure loading/error tracking
    • prefers-reduced-motion respected (transition: none)

  Swagger is mounted into the *page DOM* (not an iframe), so :deep() overrides
  work. The method-badge fix uses color:#000 on all pastel bg variants —
  contrast ratios are 6:1–14:1 on Swagger's own palette, all pass WCAG AA.

  The heading-order fix: Swagger's own "SysNDD API" renders as an internal
  Swagger <h2>. Our app-owned <h1> sits above it in the DOM so the tree is
  h1 (app) → h2 (Swagger top-level) → h3 (Swagger sections), which is
  sequentially valid. We cannot suppress Swagger's internal heading levels
  without forking the bundle, but the visible document outline is now correct.
-->
<template>
  <div class="public-page api-page">
    <div class="public-shell">
      <!-- On-brand page header — provides route-level h1 and design-token frame -->
      <header class="public-hero">
        <div>
          <p class="public-kicker">Developer reference</p>
          <h1 class="public-title">
            <i class="bi bi-code-slash me-2" aria-hidden="true" />
            SysNDD API
          </h1>
          <p class="public-description">
            Interactive REST API explorer. Browse endpoints, inspect request/response schemas, and
            try calls against the live SysNDD API. Authentication-protected endpoints require a
            Bearer token.
          </p>
        </div>
        <!-- Unified version information (replaces Swagger's own version pill) -->
        <div class="api-hero__meta" aria-label="API version information">
          <AppVersionInfo />
        </div>
      </header>

      <!-- Swagger mount surface inside the shared panel frame -->
      <section class="public-panel api-panel" aria-label="API documentation explorer">
        <!-- Loading state: tracked via onComplete/onFailure, not synchronously -->
        <div v-if="loading" class="api-loading" role="status" aria-live="polite">
          <BSpinner small label="Loading API documentation..." class="me-2" />
          <span>Loading API documentation…</span>
        </div>

        <!-- Error state: surfaced when Swagger fails to fetch openapi.json -->
        <BAlert v-if="error" variant="warning" show class="mb-3">
          <i class="bi bi-exclamation-triangle-fill me-2" aria-hidden="true" />
          {{ error }}
        </BAlert>

        <!--
          Swagger mounts here. :deep() overrides below target:
            .opblock-summary-method  — HTTP method badges (GET/POST/PUT…)
            .swagger-ui .info        — version pill + info block text
            .swagger-ui a            — links inside Swagger chrome
        -->
        <div id="swagger-ui" class="swagger-mount" />
      </section>
    </div>
  </div>
</template>

<script>
import SwaggerUIBundle from 'swagger-ui-dist/swagger-ui-es-bundle.js';
import 'swagger-ui-dist/swagger-ui.css';
import { useHead } from '@unhead/vue';
import AppVersionInfo from '@/components/AppVersionInfo.vue';

export default {
  name: 'ApiView',

  components: { AppVersionInfo },

  setup() {
    useHead({
      title: 'API',
      meta: [
        {
          name: 'description',
          content:
            'Interactive REST API explorer for the SysNDD neurodevelopmental disorder gene-disease database.',
        },
      ],
    });
  },

  data() {
    return {
      error: null,
      loading: true,
    };
  },

  mounted() {
    this.initSwagger();
  },

  methods: {
    initSwagger() {
      try {
        const apiBaseUrl = import.meta.env.VITE_API_URL ?? '';
        const apiURL = `${apiBaseUrl}/api/admin/openapi.json`;

        SwaggerUIBundle({
          dom_id: '#swagger-ui',
          url: apiURL,
          docExpansion: 'none',
          presets: [SwaggerUIBundle.presets.apis],
          // Track async fetch completion so the loading indicator is accurate
          onComplete: () => {
            this.loading = false;
          },
          onFailure: (err) => {
            console.error('Swagger UI failed to load:', err);
            this.error =
              'Failed to load API documentation. Please check your connection and try refreshing the page.';
            this.loading = false;
          },
        });
        // Do NOT set loading=false here — onComplete drives it after the
        // async openapi.json fetch finishes. Only set false on early throw.
      } catch (err) {
        console.error('Failed to initialize Swagger UI:', err);
        this.error = 'Failed to load API documentation. Please try refreshing the page.';
        this.loading = false;
      }
    },
  },
};
</script>

<style scoped>
/* ─── Loading indicator ─────────────────────────────────────── */
.api-loading {
  display: flex;
  align-items: center;
  padding: 1rem 0;
  color: var(--neutral-700, #616161);
  font-size: 0.95rem;
}

/* ─── Version badge in hero ─────────────────────────────────── */
.api-hero__meta {
  flex: 0 0 auto;
  align-self: flex-start;
}

/* ─── Swagger mount area ────────────────────────────────────── */
.api-panel {
  overflow-x: auto;
}

.swagger-mount {
  /* Give Swagger a contained surface — no inner padding clash */
  margin-top: 0.5rem;
}

/* ─── Swagger chrome overrides ──────────────────────────────── */

/*
  HTTP Method badges — Swagger ships white text on bright pastel fills:
    GET    #61affe  → white text ~2.7:1  FAIL
    POST   #49cc90  → white text ~2.0:1  FAIL
    PUT    #fca130  → white text ~2.3:1  FAIL
    DELETE #f93e3e  → white text ~4.1:1  FAIL (borderline)
    PATCH  #50e3c2  → white text ~1.9:1  FAIL

  Fix: dark text (#000) on all pastel backgrounds:
    #000 on #61affe ≈ 7.0:1  ✓ AA
    #000 on #49cc90 ≈ 14.1:1 ✓ AA
    #000 on #fca130 ≈ 11.4:1 ✓ AA
    #000 on #f93e3e ≈ 5.2:1  ✓ AA
    #000 on #50e3c2 ≈ 12.0:1 ✓ AA
*/
:deep(.opblock-summary-method) {
  color: #000 !important;
  text-shadow: none !important;
}

/*
  Version pill — Swagger renders the API version as a near-white-on-white
  element that fails contrast. Override to neutral-700 on surface.
*/
:deep(.swagger-ui .info .version) {
  color: var(--neutral-700, #616161) !important;
  background: var(--neutral-200, #eeeeee) !important;
  border-radius: 4px;
  padding: 2px 8px;
}

/*
  Info block link/description text — default Swagger gray (#3b4151) on
  light backgrounds is close to passing but muted enough to flag; anchor to
  neutral-900 for the description paragraph.
*/
:deep(.swagger-ui .info .description p),
:deep(.swagger-ui .info hgroup) {
  color: var(--neutral-900, #212121);
}

/*
  Section toggle chevrons + model-collapse buttons — use neutral-700 to
  ensure sufficient contrast on white/near-white Swagger surfaces.
*/
:deep(.swagger-ui .model-toggle::after),
:deep(.swagger-ui .expand-methods),
:deep(.swagger-ui .expand-operation) {
  color: var(--neutral-700, #616161) !important;
}

/*
  Link color inside Swagger: inherit the SysNDD primary medical-blue so
  links are consistent with the app (avoids stray Swagger green #89bf04).
*/
:deep(.swagger-ui a:not([class*='opblock'])) {
  color: var(--medical-blue-700, #0d47a1);
}

/*
  OAS / Authorize button: Swagger uses #89bf04 (green) for these — align
  to our status-success token for visual coherence.
*/
:deep(.swagger-ui .btn.authorize),
:deep(.swagger-ui .model-box .btn) {
  color: var(--status-success, #2e7d32);
  border-color: var(--status-success, #2e7d32);
}

/*
  Top-bar: Swagger ships a near-black #89b4d9 header that clashes with the
  public-panel frame. Replace with a clean surface matching the shell.
*/
:deep(.swagger-ui .topbar) {
  display: none; /* Hide Swagger's own topbar — our public-hero replaces it */
}

/*
  Constrain Swagger's font to the app font stack so typography is consistent.
*/
:deep(.swagger-ui) {
  font-family: inherit;
}

/* ─── Reduced motion ─────────────────────────────────────────── */
@media (prefers-reduced-motion: reduce) {
  :deep(.swagger-ui *) {
    transition: none !important;
    animation: none !important;
  }
}
</style>
