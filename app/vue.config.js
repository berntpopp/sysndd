const BootstrapVueLoader = require('bootstrap-vue-loader')
const SitemapPlugin = require('sitemap-webpack-plugin').default;

// object paths

const paths = [
  {
    path: '/',
    priority: 1.0,
    changefreq: 'monthly'
  },
  {
    path: '/Entities',
    priority: 0.9,
    changefreq: 'monthly'
  },
  {
    path: '/Genes',
    priority: 0.9,
    changefreq: 'monthly'
  },
  {
    path: '/Phenotypes',
    priority: 0.9,
    changefreq: 'monthly'
  },
  {
    path: '/CurationComparisons',
    priority: 0.8,
    changefreq: 'monthly'
  },
  {
    path: '/PhenotypeCorrelations',
    priority: 0.8,
    changefreq: 'monthly'
  },
  {
    path: '/EntriesOverTime',
    priority: 0.8,
    changefreq: 'monthly'
  },
  {
    path: '/GeneNetworks',
    priority: 0.8,
    changefreq: 'monthly'
  },
  {
    path: '/About',
    priority: 0.5,
    changefreq: 'yearly'
  },
  {
    path: '/Login',
    priority: 0.5,
    changefreq: 'yearly'
  },
  {
    path: '/Register',
    priority: 0.5,
    changefreq: 'yearly'
  }
]

// transpileDependencies and devtool source-map based on https://stackoverflow.com/questions/59693708/how-can-i-activate-the-sourcemap-for-vue-cli-4
// prefetch delete based on https://github.com/vuejs/vue-cli/issues/979
// module in webpack fpr pinia import based on: https://github.com/vuejs/pinia/issues/675
module.exports = {
    configureWebpack: {
        plugins: [ new BootstrapVueLoader(), new SitemapPlugin({ base: 'https://sysndd.dbmr.unibe.ch/', paths, options: {lastmod: true} }) ],
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