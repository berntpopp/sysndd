const BootstrapVueLoader = require('bootstrap-vue-loader')

// transpileDependencies and devtool source-map based on https://stackoverflow.com/questions/59693708/how-can-i-activate-the-sourcemap-for-vue-cli-4
// prefetch delete based on https://github.com/vuejs/vue-cli/issues/979
module.exports = {
    configureWebpack: {
        plugins: [ new BootstrapVueLoader() ]
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