# Phase 12: Build Tool Migration (Vite) - Research

**Researched:** 2026-01-23
**Domain:** Vite 7 migration from Vue CLI 5 + Webpack
**Confidence:** HIGH

## Summary

Vite 7 is the current standard for Vue 3 development, offering instant dev server startup and fast Hot Module Replacement (HMR). The migration from Vue CLI/Webpack requires systematic changes to configuration, environment variables, import patterns, and Docker integration.

**Current project state:** Vue CLI 5.0.8 with Webpack 5, Vue 3.5 via @vue/compat, 156 environment variable references using VUE_APP_* prefix, Docker-first development workflow with HMR requirements.

**Migration complexity:** Medium - straightforward for standard patterns, requires attention to webpack-specific code (require.context, magic comments), file extension requirements, and Docker HMR configuration.

**Primary recommendation:** Use Vite 7.3+ with @vitejs/plugin-vue 5.x, migrate all VUE_APP_* to VITE_* (156 references), enable polling for Docker HMR, configure manual chunks for vendor splitting, use hidden source maps for production.

## Standard Stack

The established libraries/tools for Vite + Vue 3 migration:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| vite | 7.3+ | Build tool and dev server | Official Vue 3 recommendation, 31M weekly downloads, replaces Vue CLI |
| @vitejs/plugin-vue | 5.1+ | Vue 3 SFC support | Official Vue plugin for Vite, handles .vue compilation |
| vite-plugin-pwa | 1.0+ | PWA support | Zero-config PWA plugin, replaces @vue/cli-plugin-pwa |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| sass | 1.53+ | CSS preprocessor | Already in project, SCSS compilation |
| vite-plugin-html | Optional | HTML templating | If dynamic index.html values needed beyond hardcoding |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| vite-plugin-pwa | Custom service worker | Plugin provides zero-config, workbox integration, manifest generation |
| Manual env migration | webpack-to-vite tool | Automated tool may miss edge cases, manual ensures accuracy |

**Installation:**
```bash
npm install -D vite@^7.3.0 @vitejs/plugin-vue@^5.1.0 vite-plugin-pwa@^1.0.0
```

**Node.js Requirements:**
- Minimum: Node.js 20.19+ or 22.12+ (Vite 7 requirement)
- Recommended: Node.js 24.x LTS (Krypton) - Active LTS until April 2028
- Current project: Node.js 24.5.0 (already compatible)

## Architecture Patterns

### Recommended Project Structure
```
app/
├── index.html           # MOVE from public/ to root (Vite entry point)
├── vite.config.ts       # NEW - replaces vue.config.js
├── public/              # Static assets (copied as-is)
│   ├── img/
│   └── favicon.ico
├── src/
│   ├── main.js          # Add .vue extensions to all imports
│   ├── components/      # Add .vue extensions to all imports
│   ├── views/           # Add .vue extensions to all imports
│   └── router/
├── .env.development     # Migrate VUE_APP_* → VITE_*
├── .env.production      # Migrate VUE_APP_* → VITE_*
├── .env.docker          # Migrate VUE_APP_* → VITE_*
└── dist/                # Build output (unchanged)
```

### Pattern 1: Vite Configuration File
**What:** TypeScript-based configuration with Vue plugin and PWA support
**When to use:** Primary Vite setup, replaces vue.config.js
**Example:**
```typescript
// Source: https://vite.dev/config/
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    vue(),
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        skipWaiting: true
      },
      manifest: {
        name: 'SysNDD',
        short_name: 'SysNDD',
        theme_color: '#EAADBA',
        icons: [/* migrate from vue.config.js */]
      }
    })
  ],
  resolve: {
    alias: {
      '@': '/src',
      'vue': '@vue/compat' // Keep until compat removed
    }
  },
  server: {
    host: '0.0.0.0', // Docker requirement
    port: 5173,      // Vite default, avoid conflicts
    proxy: {
      '/api': {
        target: 'http://backend-service:3000',
        changeOrigin: true
      }
    },
    watch: {
      usePolling: true  // CRITICAL for Docker HMR
    }
  },
  css: {
    preprocessorOptions: {
      scss: {
        additionalData: '@use "@/assets/scss/custom.scss" as *;',
        api: 'modern-compiler' // Vite 5.4+ for @use support
      }
    }
  },
  build: {
    outDir: 'dist',
    sourcemap: 'hidden',
    rollupOptions: {
      output: {
        manualChunks: {
          'vendor': ['vue', 'vue-router', 'pinia'],
          'bootstrap': ['bootstrap', 'bootstrap-vue-next']
        }
      }
    }
  }
})
```

### Pattern 2: Environment Variable Migration
**What:** Replace process.env.VUE_APP_* with import.meta.env.VITE_*
**When to use:** All 156 environment variable references in codebase
**Example:**
```javascript
// Source: https://vite.dev/guide/env-and-mode

// BEFORE (Vue CLI/Webpack):
const apiUrl = `${process.env.VUE_APP_API_URL}/api/endpoint`
const mode = process.env.VUE_APP_MODE

// AFTER (Vite):
const apiUrl = `${import.meta.env.VITE_API_URL}/api/endpoint`
const mode = import.meta.env.VITE_MODE

// Built-in Vite constants:
if (import.meta.env.DEV) { /* development only */ }
if (import.meta.env.PROD) { /* production only */ }
```

**.env file migration:**
```bash
# BEFORE (.env.docker):
VUE_APP_API_URL="http://localhost"
VUE_APP_URL="http://localhost"
VUE_APP_MODE="docker"

# AFTER (.env.docker):
VITE_API_URL="http://localhost"
VITE_URL="http://localhost"
VITE_MODE="docker"
```

### Pattern 3: Index.html Migration
**What:** Move index.html to root, replace Webpack placeholders
**When to use:** Required - index.html is Vite's entry point
**Example:**
```html
<!-- Source: https://vueschool.io/articles/vuejs-tutorials/how-to-migrate-from-vue-cli-to-vite/ -->

<!-- BEFORE (public/index.html - Vue CLI): -->
<link rel="icon" href="<%= BASE_URL %>favicon.ico">
<title><%= htmlWebpackPlugin.options.title %></title>

<!-- AFTER (index.html - Vite): -->
<link rel="icon" href="/favicon.ico">
<title>SysNDD</title>

<!-- Add Vite entry point script: -->
<script type="module" src="/src/main.js"></script>
```

### Pattern 4: Dynamic Imports (require.context → import.meta.glob)
**What:** Replace Webpack-specific require.context with Vite's import.meta.glob
**When to use:** Any code using require.context for dynamic imports
**Example:**
```javascript
// Source: https://limberg.dev/blog/porting-webpack-glob-imports-to-vite

// BEFORE (Webpack):
const modules = require.context('./components', false, /\.vue$/)
modules.keys().forEach(key => {
  const component = modules(key).default
})

// AFTER (Vite - eager loading):
const modules = import.meta.glob('./components/*.vue', { eager: true })
Object.entries(modules).forEach(([path, module]) => {
  const component = module.default
})

// AFTER (Vite - async loading):
const modules = import.meta.glob('./components/*.vue')
for (const path in modules) {
  const module = await modules[path]()
  const component = module.default
}
```

### Pattern 5: Docker Development Configuration
**What:** Docker setup with HMR support using polling
**When to use:** Docker-first development workflow (primary workflow for this project)
**Example:**
```dockerfile
# Source: https://www.restack.io/p/vite-answer-docker-hmr-guide

# Dockerfile.dev
FROM node:24-alpine
WORKDIR /app

COPY package*.json ./
RUN npm ci

ENV NODE_ENV=development
ENV HOST=0.0.0.0

EXPOSE 5173

CMD ["npm", "run", "dev"]
```

```yaml
# docker-compose.yml excerpt
services:
  app:
    build:
      context: ./app
      dockerfile: Dockerfile.dev
    volumes:
      - ./app/src:/app/src        # Mount source code
      - ./app/public:/app/public  # Mount public assets
    ports:
      - "5173:5173"
    environment:
      - NODE_ENV=development
```

**vite.config.ts for Docker:**
```typescript
server: {
  host: '0.0.0.0',           // Listen on all interfaces
  port: 5173,
  strictPort: true,          // Fail if port unavailable
  watch: {
    usePolling: true,        // REQUIRED for Docker HMR
    interval: 100            // Polling interval (ms)
  },
  hmr: {
    clientPort: 5173         // Match exposed port
  }
}
```

### Pattern 6: Production Build with Manual Chunks
**What:** Vendor chunk splitting for optimal caching
**When to use:** Production builds to reduce main bundle size
**Example:**
```typescript
// Source: https://shaxadd.medium.com/optimizing-your-react-vite-application-a-guide-to-reducing-bundle-size-6b7e93891c96

build: {
  rollupOptions: {
    output: {
      manualChunks: {
        // Core Vue dependencies
        'vendor': ['vue', 'vue-router', 'pinia'],

        // Bootstrap UI framework
        'bootstrap': ['bootstrap', 'bootstrap-vue-next'],

        // Large visualization libraries
        'viz': ['d3', '@upsetjs/bundle', 'gsap'],

        // Utilities
        'utils': ['axios', 'file-saver', 'joi']
      }
    }
  }
}
```

### Anti-Patterns to Avoid
- **Omitting .vue extensions in imports:** Vite requires explicit extensions for non-JS files, causes MIME type errors
- **Using process.env instead of import.meta.env:** Won't work in Vite, must use import.meta.env
- **Forgetting usePolling in Docker:** HMR won't work without polling in containerized environments
- **Public source maps in production:** Security risk, use 'hidden' to generate maps without exposing them
- **Not setting server.host to 0.0.0.0:** Dev server won't be accessible from outside container

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PWA manifest and service worker | Custom service worker generation | vite-plugin-pwa | Handles workbox integration, manifest generation, update strategies, development mode |
| Environment variable injection | Custom env loader | Vite's built-in import.meta.env | Secure VITE_* prefix filtering, mode-based .env files, type safety |
| Code splitting strategy | Manual bundle analysis and splitting | manualChunks in rollupOptions | Rollup handles dependency graphs, shared chunks, circular dependencies |
| SCSS global imports | Manual @import in every component | css.preprocessorOptions.additionalData | Automatic injection, supports modern @use with api: 'modern-compiler' |
| Docker HMR | Custom file watcher | server.watch.usePolling | Handles Docker volume mount timing issues, WSL2 compatibility |

**Key insight:** Vite provides built-in solutions for most webpack-dev-server and Vue CLI plugin functionality. Migration is about configuration, not custom tooling.

## Common Pitfalls

### Pitfall 1: File Extensions Required for .vue Files
**What goes wrong:** Imports like `import Tooltip from '@/components/Tooltip'` fail with MIME type errors
**Why it happens:** Vite uses native ES modules which require explicit extensions for non-JS files, webpack allowed omitting extensions
**How to avoid:** Add .vue extension to all component imports during migration
**Warning signs:** Browser error: "The server responded with a non-JavaScript MIME type of 'text/html'"
**Verification:**
```bash
# Search for imports without .vue extension
grep -r "from ['\"].*components.*['\"]" src/ | grep -v "\.vue['\"]"
```

### Pitfall 2: Docker HMR Not Working Without Polling
**What goes wrong:** File changes don't trigger HMR in Docker containers, requires manual refresh
**Why it happens:** Docker volume mounts don't trigger filesystem events reliably, especially on Windows/WSL2
**How to avoid:** Always set `server.watch.usePolling: true` in vite.config when using Docker
**Warning signs:** Dev server starts successfully but changes don't trigger HMR, console shows no update messages
**Trade-off:** Polling increases CPU usage, but required for Docker HMR functionality

### Pitfall 3: process.env References Still in Code
**What goes wrong:** Environment variables return undefined, API calls fail
**Why it happens:** Vite doesn't inject process.env, uses import.meta.env instead
**How to avoid:** Systematic search and replace of all process.env.VUE_APP_* references (156 in this project)
**Warning signs:** Console errors about undefined API URLs, app makes requests to "undefined/api/endpoint"
**Migration steps:**
```bash
# Find all process.env usages
grep -r "process\.env" src/

# Replace pattern:
# FROM: process.env.VUE_APP_API_URL
# TO:   import.meta.env.VITE_API_URL
```

### Pitfall 4: Circular Dependencies Break HMR
**What goes wrong:** HMR stops working, full page reload on every change, or build failures
**Why it happens:** Vite's HMR is stricter about circular dependencies than Webpack
**How to avoid:** Review and refactor circular imports, especially in composables and stores
**Warning signs:** Console warnings about circular dependencies, HMR falls back to full reload
**Detection:**
```bash
# Use vite-plugin-circular-dependency (dev dependency)
npm install -D vite-plugin-circular-dependency
```

### Pitfall 5: BASE_URL and htmlWebpackPlugin Not Replaced
**What goes wrong:** index.html fails to load, broken icon paths, title shows literal "<%= htmlWebpackPlugin.options.title %>"
**Why it happens:** Vite doesn't process EJS templates like webpack's HtmlWebpackPlugin
**How to avoid:** Replace all `<%= BASE_URL %>` with `/` and `<%= htmlWebpackPlugin.options.title %>` with hardcoded values
**Warning signs:** HTML source shows literal template syntax, browser 404s on asset paths
**Migration:**
```html
<!-- REMOVE these patterns: -->
<%= BASE_URL %>
<%= htmlWebpackPlugin.options.title %>

<!-- REPLACE with: -->
/
Hard Coded Title

<!-- OR use import.meta.env.BASE_URL in JavaScript for dynamic paths -->
```

### Pitfall 6: SCSS @import Syntax with additionalData
**What goes wrong:** Global SCSS variables not available in components, compilation errors
**Why it happens:** Sass deprecated @import, Vite 5.4+ requires @use with modern-compiler API
**How to avoid:** Use `@use` syntax with `as *` for global namespace, set `api: 'modern-compiler'`
**Warning signs:** "Undefined variable" errors in components that should have global SCSS access
**Correct configuration:**
```typescript
css: {
  preprocessorOptions: {
    scss: {
      additionalData: '@use "@/assets/scss/custom.scss" as *;',
      api: 'modern-compiler'  // Required for @use in additionalData
    }
  }
}
```

### Pitfall 7: Production Source Maps Exposed Publicly
**What goes wrong:** Source code visible to anyone viewing production site, intellectual property leak
**Why it happens:** Vite's `sourcemap: true` generates .js.map files and includes sourcemap comments in bundles
**How to avoid:** Use `sourcemap: 'hidden'` to generate maps without browser-visible comments
**Warning signs:** .js.map files in production dist/, browser DevTools show original source code
**Security best practice:**
```typescript
build: {
  sourcemap: 'hidden'  // Generates maps without comments
}
// Then: Upload maps to error monitoring (Sentry) and delete from dist/
```

### Pitfall 8: require.context Not Migrated
**What goes wrong:** Build fails with "require is not defined" error
**Why it happens:** Vite uses native ES modules, no CommonJS require support
**How to avoid:** Replace all require.context with import.meta.glob (eager: true for sync behavior)
**Warning signs:** "ReferenceError: require is not defined" during build
**Migration pattern:** See Pattern 4 above

### Pitfall 9: Wrong Port Configuration Causes Access Issues
**What goes wrong:** Dev server unreachable from host machine or Traefik proxy
**Why it happens:** Not exposing correct port in Docker, or HMR clientPort mismatch
**How to avoid:** Match vite.config port with Docker expose/publish ports, set hmr.clientPort
**Warning signs:** "Failed to connect to WebSocket" in browser console, HMR doesn't work through proxy
**Docker configuration:**
```typescript
// vite.config.ts
server: {
  port: 5173,
  hmr: {
    clientPort: 5173  // Must match exposed port browser sees
  }
}

// docker-compose.yml
ports:
  - "5173:5173"  # Match internal and external ports
```

### Pitfall 10: Legacy Node APIs Cause Build Failures
**What goes wrong:** Build fails with "Buffer is not defined" or "crypto is not defined"
**Why it happens:** Vite doesn't polyfill Node.js APIs by default, some old libraries expect them
**How to avoid:** Use vite-plugin-node-polyfills or refactor to modern libraries
**Warning signs:** "Buffer is not defined", "global is not defined", "process is not defined" errors
**Not expected in this project:** Using modern Vue 3 libraries, but watch for older dependencies

## Code Examples

Verified patterns from official sources:

### Basic vite.config.ts Structure
```typescript
// Source: https://vite.dev/config/
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': '/src'
    }
  },
  server: {
    port: 5173
  },
  build: {
    outDir: 'dist'
  }
})
```

### Environment Variable Access
```javascript
// Source: https://vite.dev/guide/env-and-mode

// .env.production
VITE_API_URL=https://api.production.com
VITE_FEATURE_FLAG=true

// In application code:
console.log(import.meta.env.VITE_API_URL)
console.log(import.meta.env.MODE)  // 'development' or 'production'
console.log(import.meta.env.PROD)  // boolean
console.log(import.meta.env.DEV)   // boolean
```

### Package.json Scripts
```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "build:docker": "vite build --mode docker",
    "build:production": "vite build --mode production"
  }
}
```

### Docker Dockerfile.dev for Vite
```dockerfile
# Source: Project's existing Dockerfile.dev pattern + Vite requirements
FROM node:24-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci

ENV NODE_ENV=development
ENV HOST=0.0.0.0

EXPOSE 5173

CMD ["npm", "run", "dev"]
```

### Production Dockerfile with Vite
```dockerfile
# Source: Project's existing Dockerfile pattern + Vite build
ARG NODE_VERSION=24
ARG NGINX_VERSION=1.27.4

FROM node:${NODE_VERSION}-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci --no-audit --no-fund

COPY . .
RUN npm run build

# Stage 2: nginx (unchanged from current setup)
FROM fholzer/nginx-brotli:latest AS production
# ... rest of nginx config
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Vue CLI | Vite | 2021+ | Vue CLI in maintenance mode, Vite is official recommendation |
| Webpack | Vite + Rollup | 2021+ | 10-100x faster dev server startup, instant HMR |
| webpack-dev-server | Vite dev server | 2021+ | Native ES modules, no bundling in dev |
| VUE_APP_* env vars | VITE_* env vars | Vite adoption | Security: explicit VITE_ prefix for client exposure |
| require.context | import.meta.glob | Vite adoption | Native ES module pattern |
| @import (Sass) | @use / @forward | 2022+ | Sass deprecated @import, Vite 5.4+ supports modern API |
| Node.js 18 | Node.js 20.19+ / 22.12+ / 24 LTS | Vite 7 (2025) | Node 18 EOL April 2025 |
| Vite 6 | Vite 7 | December 2025 | Browser target 'baseline-widely-available', Rolldown bundler option |

**Deprecated/outdated:**
- **Vue CLI:** Officially in maintenance mode, no new features, migrate to Vite
- **@vue/cli-plugin-pwa:** Replace with vite-plugin-pwa
- **splitVendorChunkPlugin:** Removed in Vite 7, use manual chunks instead
- **Sass legacy API:** Deprecated, use api: 'modern-compiler' in Vite 5.4+
- **resolve.extensions for .vue:** Not recommended, explicitly include extensions

## Open Questions

Things that couldn't be fully resolved:

1. **Exact API proxy configuration**
   - What we know: Current vue.config.js doesn't show explicit proxy config, .env files show different API URLs per mode
   - What's unclear: Whether proxy is needed if API accessible at /api path or if Traefik handles routing
   - Recommendation: Configure proxy for /api → backend service during planning based on docker-compose.yml inspection

2. **Webpack magic comments for chunk naming**
   - What we know: Need to search for webpackChunkName comments in dynamic imports
   - What's unclear: Whether project uses route-based code splitting with magic comments
   - Recommendation: Search codebase for `webpackChunkName` during planning, convert to Vite patterns

3. **Source map upload workflow**
   - What we know: Should use 'hidden' source maps for security
   - What's unclear: Whether project uses error monitoring (Sentry, etc.) requiring source map upload
   - Recommendation: If no error monitoring, use sourcemap: false for production; if yes, configure upload and deletion

4. **PostCSS and PurgeCSS configuration**
   - What we know: Project uses @fullhuman/postcss-purgecss plugin
   - What's unclear: How PurgeCSS is configured in Vue CLI setup, whether postcss.config.js exists
   - Recommendation: Search for postcss.config.js, migrate to Vite's PostCSS support if exists

## Current Project Inventory

Based on codebase analysis:

### Environment Variables
**Total references:** 156 usages of `process.env.VUE_APP_*`

**Variables in use:**
- `VUE_APP_API_URL` - API base URL (varies by mode)
- `VUE_APP_URL` - Application base URL
- `VUE_APP_MODE` - Runtime mode indicator

**Environment files:**
- `.env` - Root level (Docker Compose vars)
- `app/.env` - App-level defaults
- `app/.env.development` - Local dev (API on localhost:7778)
- `app/.env.docker` - Docker dev (API via Traefik)
- `app/.env.production` - Production (sysndd.org)

**Migration impact:** All 156 references must change from `process.env.VUE_APP_*` to `import.meta.env.VITE_*`

**Security audit:** No sensitive secrets found in environment variables - all are URLs and mode flags (safe to expose client-side)

### Current Webpack Configuration
**File:** `app/vue.config.js`

**Key configurations to migrate:**
- Vue 3 compat alias (`vue: '@vue/compat'`) - Keep during migration
- PWA configuration - Migrate to vite-plugin-pwa
- SCSS prependData - Migrate to additionalData with @use syntax
- devServer.host: '0.0.0.0' - Keep for Docker
- devServer.allowedHosts: 'all' - Traefik reverse proxy support
- Babel cache: '/tmp/babel-cache' - Remove, Vite doesn't use Babel

**Webpack-specific code to remove:**
- webpack.DefinePlugin for Vue feature flags
- .mjs module type rule
- BootstrapVueLoader (already disabled)

### Index.html Placeholders
**File:** `app/public/index.html`

**Replacements needed:**
- `<%= BASE_URL %>` → `/` (multiple occurrences)
- `<%= htmlWebpackPlugin.options.title %>` → `SysNDD`
- Add `<script type="module" src="/src/main.js"></script>` before closing `</body>`

### Node.js Version
**Current:** Node.js 24.5.0 (detected via `node --version`)
**Required:** Node.js 20.19+ or 22.12+ (Vite 7 minimum)
**Recommended:** Node.js 24.x LTS (Krypton) - Active LTS until April 2028
**Status:** ✅ Already compatible, no upgrade needed

### Port Selection
**Current ports in use:**
- `8080` - Current webpack-dev-server port (app/.env.development)
- `7778` - Backend API port (assumed from .env)

**Recommended Vite port:** `5173` (default, avoids conflict with 8080)
**Rationale:**
- 5173 is Vite's default, well-documented
- No conflict with existing 8080 or 7778 services
- Different port makes parallel Vue CLI/Vite testing possible
- Preview server on 4173 (Vite default)

## Sources

### Primary (HIGH confidence)
- Vite Official Documentation - https://vite.dev/guide/
- Vite Config Reference - https://vite.dev/config/
- Vite Environment Variables - https://vite.dev/guide/env-and-mode
- Vite Server Options - https://vite.dev/config/server-options
- Vite Build Options - https://vite.dev/config/build-options
- Vite 7.0 Release Notes - https://vite.dev/blog/announcing-vite7
- Node.js Releases - https://nodejs.org/en/about/previous-releases

### Secondary (MEDIUM confidence)
- Vue School: How to Migrate from Vue CLI to Vite - https://vueschool.io/articles/vuejs-tutorials/how-to-migrate-from-vue-cli-to-vite/
- Vue School: Environment Variables in Vite - https://vueschool.io/articles/vuejs-tutorials/how-to-use-environment-variables-in-vite-js/
- Vite Plugin PWA Official Docs - https://vite-pwa-org.netlify.app/
- Medium: Differences Between vite.config.ts and vue.config.js - https://medium.com/@melthaw/differences-between-vite-config-ts-and-vue-config-js-in-vue-3-8ec92ad4b01b
- Limberg Dev: Porting Webpack glob imports to Vite - https://limberg.dev/blog/porting-webpack-glob-imports-to-vite
- Restack: Vite Docker HMR Guide - https://www.restack.io/p/vite-answer-docker-hmr-guide

### Tertiary (LOW confidence - WebSearch only, flagged for validation)
- FiveJars: Vue, Nuxt & Vite Status in 2026 - https://fivejars.com/insights/vue-nuxt-vite-status-for-2026-risks-priorities-architecture-updates/
- Medium: Vite vs. Webpack Migration Guide - https://dev.to/pockit_tools/vite-vs-webpack-in-2026-a-complete-migration-guide-and-deep-performance-analysis-5ej5
- Medium: Optimizing Your Vite Application - https://shaxadd.medium.com/optimizing-your-react-vite-application-a-guide-to-reducing-bundle-size-6b7e93891c96

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Vite docs, npm package info, official Vue recommendation
- Architecture: HIGH - Official docs for config patterns, project codebase analysis completed
- Pitfalls: MEDIUM to HIGH - Mix of official docs (HIGH) and community experiences (MEDIUM)
- Docker HMR: HIGH - Official docs + community consensus on polling requirement
- Environment variables: HIGH - 156 references inventoried, .env files analyzed

**Research date:** 2026-01-23
**Valid until:** 2026-03-23 (60 days - Vite is stable, but active development)

**Notes:**
- Vite 7 is current stable (released December 2025)
- Node.js 24 LTS is recommended (project already using 24.5.0)
- 156 environment variable references require migration
- Docker HMR requires polling - critical for primary dev workflow
- No blocking issues found for migration
