import { fileURLToPath, URL } from 'node:url';
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { VitePWA } from 'vite-plugin-pwa';
import { visualizer } from 'rollup-plugin-visualizer';
import type { PluginOption } from 'vite';

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    vue(),
    VitePWA({
      registerType: 'prompt',
      manifest: {
        name: 'SysNDD',
        short_name: 'SysNDD',
        start_url: './',
        theme_color: '#EAADBA',
        icons: [
          {
            src: './img/icons/android-chrome-192x192.png',
            sizes: '192x192',
            type: 'image/png',
          },
          {
            src: './img/icons/android-chrome-512x512.png',
            sizes: '512x512',
            type: 'image/png',
          },
          {
            src: './img/icons/android-chrome-maskable-192x192.png',
            sizes: '192x192',
            type: 'image/png',
            purpose: 'maskable',
          },
          {
            src: './img/icons/android-chrome-maskable-512x512.png',
            sizes: '512x512',
            type: 'image/png',
            purpose: 'maskable',
          },
          {
            src: './img/icons/apple-touch-icon-60x60.png',
            sizes: '60x60',
            type: 'image/png',
          },
          {
            src: './img/icons/apple-touch-icon-76x76.png',
            sizes: '76x76',
            type: 'image/png',
          },
          {
            src: './img/icons/apple-touch-icon-120x120.png',
            sizes: '120x120',
            type: 'image/png',
          },
          {
            src: './img/icons/apple-touch-icon-152x152.png',
            sizes: '152x152',
            type: 'image/png',
          },
          {
            src: './img/icons/apple-touch-icon-180x180.png',
            sizes: '180x180',
            type: 'image/png',
          },
          {
            src: './img/icons/apple-touch-icon.png',
            sizes: '180x180',
            type: 'image/png',
          },
          {
            src: './img/icons/favicon-16x16.png',
            sizes: '16x16',
            type: 'image/png',
          },
          {
            src: './img/icons/favicon-32x32.png',
            sizes: '32x32',
            type: 'image/png',
          },
          {
            src: './img/icons/msapplication-icon-144x144.png',
            sizes: '144x144',
            type: 'image/png',
          },
          {
            src: './img/icons/mstile-150x150.png',
            sizes: '150x150',
            type: 'image/png',
          },
        ],
      },
    }),
    visualizer({
      filename: './dist/stats.html',
      open: process.env.ANALYZE === 'true',
      gzipSize: true,
      brotliSize: true,
      template: 'treemap',
    }) as unknown as PluginOption,
  ],

  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },

  // Vue 3 feature flags (replaces webpack.DefinePlugin)
  define: {
    __VUE_OPTIONS_API__: true,
    __VUE_PROD_DEVTOOLS__: false,
    __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: false,
  },

  server: {
    host: '0.0.0.0', // Docker requirement
    port: 5173, // Vite default, avoids conflict with Vue CLI 8080
    strictPort: true, // Fail if port unavailable
    watch: {
      usePolling: true, // CRITICAL for Docker HMR
      interval: 100,
    },
    hmr: {
      clientPort: 5173,
    },
    // API Proxy - routes /api requests to the backend via Traefik
    // In Docker: uses Traefik for load balancing with sticky sessions
    // On host: set VITE_API_URL=http://localhost (through Traefik)
    proxy: {
      '/api': {
        target: process.env.VITE_API_URL || 'http://traefik:80',
        changeOrigin: true,
        // Traefik routes by Host header; inside Docker the target is 'traefik'
        // but the routing rule expects 'localhost', so override it explicitly.
        headers: { Host: 'localhost' },
      },
    },
  },

  css: {
    preprocessorOptions: {
      scss: {
        api: 'modern-compiler' as const, // For @use support
        // Note: additionalData removed - was causing circular import in custom.scss
        // SCSS variables are imported explicitly where needed
      } as any, // Temporary: Vite types don't include 'api' option yet
    },
  },

  // Optimization for dependencies that need pre-bundling
  optimizeDeps: {
    include: ['exceljs', 'ngl'],
  },

  build: {
    outDir: 'dist',
    sourcemap: 'hidden', // Security: no public source maps
    chunkSizeWarningLimit: 500, // Warn on chunks > 500KB (bootstrap is close at 300KB raw)
    rollupOptions: {
      output: {
        manualChunks: {
          // Critical path chunks (loaded on initial page load)
          vendor: ['vue', 'vue-router', 'pinia'],
          bootstrap: ['bootstrap', 'bootstrap-vue-next'],
          // Heavy visualization libraries (lazy-loaded)
          viz: ['d3', '@upsetjs/bundle', 'gsap'],
          // 3D structure viewer (lazy-loaded via BTab lazy)
          ngl: ['ngl'],
        },
      },
    },
  },
});
