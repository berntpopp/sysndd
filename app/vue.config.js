// NOTE: BootstrapVueLoader disabled for Vue 3 migration
// It requires vue-template-compiler which is Vue 2 only
// Will be removed entirely in Phase 11 (Bootstrap-Vue-Next migration)
// const BootstrapVueLoader = require('bootstrap-vue-loader');

const webpack = require('webpack');

// based on https://www.npmjs.com/package/vue-cli-plugin-sitemap#installation
// NOTE: esm package not compatible with Node.js 18+, using dynamic import instead
let routes = [];
try {
  // Import routes asynchronously for sitemap generation
  // This is only used during sitemap generation, not during dev serve
  const routesModule = require('./src/router/routes.cjs');
  routes = routesModule.routes;
} catch (e) {
  // Routes will be empty if import fails (ok for dev, sitemap cmd will handle separately)
  console.warn('Routes import skipped (expected in dev mode):', e.message);
}

// transpileDependencies and devtool source-map based on https://stackoverflow.com/questions/59693708/how-can-i-activate-the-sourcemap-for-vue-cli-4
// prefetch delete based on https://github.com/vuejs/vue-cli/issues/979
// module in webpack for pinia import based on: https://github.com/vuejs/pinia/issues/675
module.exports = {
  configureWebpack: {
    plugins: [
      // Vue 3 feature flags for proper tree-shaking
      new webpack.DefinePlugin({
        __VUE_OPTIONS_API__: true,
        __VUE_PROD_DEVTOOLS__: false,
        __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: false,
      }),
    ],
    resolve: {
      alias: {
        vue: '@vue/compat',
      },
    },
    module: {
      rules: [
        {
          test: /\.mjs$/,
          include: /node_modules/,
          type: 'javascript/auto',
        },
      ],
    },
  },
  pluginOptions: {
    sitemap: {
      baseURL: 'https://sysndd.dbmr.unibe.ch',
      outputDir: './public',
      pretty: true,
      routes,
    },
    webpackBundleAnalyzer: {
      openAnalyzer: false,
      analyzerMode: 'disabled',
    },
  },
  pwa: {
    name: 'SysNDD',
    short_name: 'SysNDD',
    start_url: './',
    appleMobileWebAppCapable: 'yes',
    appleMobileWebAppStatusBarStyle: 'black',
    themeColor: '#EAADBA',
    manifestOptions: {
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
    workboxOptions: {
      // added acording to https://stackoverflow.com/questions/54145735/vue-pwa-not-getting-new-content-after-refresh
      skipWaiting: true,
    },
  },
  devServer: {
    host: '0.0.0.0',
    // Allow requests from Traefik reverse proxy and container hostnames
    allowedHosts: 'all',
  },
  chainWebpack: (config) => {
    // A, remove the plugin
    config.plugins.delete('prefetch');

    // Vue 3 compat mode configuration
    config.resolve.alias.set('vue', '@vue/compat');
    config.module
      .rule('vue')
      .use('vue-loader')
      .tap((options) => ({
        ...options,
        compilerOptions: {
          compatConfig: {
            MODE: 2, // Vue 2 mode - maximum compatibility
          },
        },
      }));

    // Configure babel-loader cache to use /tmp to avoid permission issues
    config.module
      .rule('js')
      .use('babel-loader')
      .tap((options) => ({
        ...options,
        cacheDirectory: '/tmp/babel-cache',
      }));
  },
  css: {
    loaderOptions: {
      sass: {
        prependData: '@import "@/assets/scss/custom.scss";',
      },
    },
  },
};
