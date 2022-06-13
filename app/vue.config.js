const BootstrapVueLoader = require('bootstrap-vue-loader')

// based on https://www.npmjs.com/package/vue-cli-plugin-sitemap#installation
require = require('esm')(module);
const { routes } = require('./src/router/routes.js');

// transpileDependencies and devtool source-map based on https://stackoverflow.com/questions/59693708/how-can-i-activate-the-sourcemap-for-vue-cli-4
// prefetch delete based on https://github.com/vuejs/vue-cli/issues/979
// module in webpack for pinia import based on: https://github.com/vuejs/pinia/issues/675
module.exports = {
    configureWebpack: {
        plugins: [ new BootstrapVueLoader(), ],
        module: {
          rules: [
            {
              test: /\.mjs$/,
              include: /node_modules/,
              type: "javascript/auto"
            }
          ] 
        }
    },
    pluginOptions: {
      sitemap: {
          baseURL: 'https://sysndd.dbmr.unibe.ch',
          outputDir: './public',
          pretty: true,
          routes,
      },
    },
    pwa: {
      name: "SysNDD",
      themeColor: "#EAADBA",
      workboxOptions: {
        importWorkboxFrom: 'local',
        // added acording to https://stackoverflow.com/questions/54145735/vue-pwa-not-getting-new-content-after-refresh
        skipWaiting: true,
      }
    },
    chainWebpack: (config) => {
      // A, remove the plugin
      config.plugins.delete('prefetch')
    },
    css: {
        loaderOptions: {
          sass: {
            prependData: `@import "@/assets/scss/custom.scss";`
          }
        }
      },
}