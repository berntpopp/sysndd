const BootstrapVueLoader = require('bootstrap-vue-loader')

// transpileDependencies and devtool source-map based on https://stackoverflow.com/questions/59693708/how-can-i-activate-the-sourcemap-for-vue-cli-4
module.exports = {
    configureWebpack: {
        plugins: [ new BootstrapVueLoader() ]
    },
    css: {
        loaderOptions: {
          sass: {
            prependData: `@import "@/assets/scss/custom.scss";`
          }
        }
      }
}