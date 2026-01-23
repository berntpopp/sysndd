import { fileURLToPath, URL } from 'node:url';
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { VitePWA } from 'vite-plugin-pwa';

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    vue({
      template: {
        compilerOptions: {
          compatConfig: {
            MODE: 2, // Vue 2 mode - maximum compatibility during migration
          },
        },
      },
    }),
    VitePWA({
      registerType: 'autoUpdate',
      workbox: {
        skipWaiting: true,
      },
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
  ],

  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
      // CRITICAL: maintain compat mode during migration
      vue: '@vue/compat',
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
    // API Proxy - enables local development without Docker
    // In Docker mode, Traefik handles routing
    proxy: {
      '/api': {
        target: 'http://localhost:7778',
        changeOrigin: true,
        // Keep /api prefix since backend expects it
      },
    },
  },

  css: {
    preprocessorOptions: {
      scss: {
        api: 'modern-compiler', // For @use support
        // Note: additionalData removed - was causing circular import in custom.scss
        // SCSS variables are imported explicitly where needed
      },
    },
  },

  build: {
    outDir: 'dist',
    sourcemap: 'hidden', // Security: no public source maps
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['vue', 'vue-router', 'pinia'],
          bootstrap: ['bootstrap', 'bootstrap-vue-next'],
          viz: ['d3', '@upsetjs/bundle', 'gsap'],
        },
      },
    },
  },
});
