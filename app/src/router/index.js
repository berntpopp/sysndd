import Vue from 'vue'
import VueRouter from 'vue-router'

Vue.use(VueRouter)

const routes = [
  {
    path: '/',
    name: 'Home',
    component: () => import(/* webpackChunkName: "Home" */ '@/views/Home.vue')
  },
  {
    path: '/Entities',
    name: 'Entities',
    component: () => import(/* webpackChunkName: "Tables" */ '@/views/Entities.vue')
  },
  {
    path: '/Genes',
    name: 'Genes',
    component: () => import(/* webpackChunkName: "Tables" */ '@/views/Genes.vue')
  },
  {
    path: '/Phenotypes',
    name: 'Phenotypes',
    component: () => import(/* webpackChunkName: "Tables" */ '@/views/Phenotypes.vue')
  },
  {
    path: '/CurationComparisons',
    name: 'CurationComparisons',
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/CurationComparisons.vue')
  },
  {
    path: '/PhenotypeCorrelations',
    name: 'PhenotypeCorrelations',
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/PhenotypeCorrelations.vue')
  },
  {
    path: '/EntriesOverTime',
    name: 'EntriesOverTime',
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/EntriesOverTime.vue')
  },
  {
    path: '/GeneNetworks',
    name: 'GeneNetworks',
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/GeneNetworks.vue')
  },
  {
    path: '/Panels/:category_input?/:inheritance_input?',
    name: 'Panels',
    component: () => import(/* webpackChunkName: "Tables" */ '@/views/Panels.vue'),
    beforeEnter: (to, from, next) => {
      if (["All", "Limited", "Definitive", "Moderate", "Refuted"].includes(to.params.category_input) && ["All", "Dominant", "Other", "Recessive", "X-linked"].includes(to.params.inheritance_input) ) {
        next(); // <-- everything good, proceed
      } else {
        next({ path: '/Panels/All/All' }); // <-- redirect to setup
      }
    }
  },
  {
    path: '/About',
    name: 'About',
    component: () => import(/* webpackChunkName: "About" */ '@/views/About.vue')
  },
  {
    path: '/Login',
    name: 'Login',
    component: () => import(/* webpackChunkName: "User" */ '@/views/Login.vue')
  },
  {
    path: '/Register',
    name: 'Register',
    component: () => import(/* webpackChunkName: "User" */ '@/views/Register.vue')
  },
  {
    path: '/User',
    name: 'User',
    component: () => import(/* webpackChunkName: "User" */ '@/views/User.vue')
  },
  {
    path: '/PasswordReset/:request_jwt?',
    name: 'PasswordReset',
    component: () => import(/* webpackChunkName: "User" */ '@/views/PasswordReset.vue')
  },
  {
    path: '/Review',
    name: 'Review',
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/Review.vue'),
    beforeEnter: (to, from, next) => {
      const allowed_roles = ["Administrator", "Curator", "Reviewer"];
      let expires = 0;
      let timestamp = 0;
      let user_role = "Viewer";
      
      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) next({ name: 'Login' })
      else next();
    }
  },
  {
    path: '/Curate',
    name: 'Curate',
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/Curate.vue'),
    beforeEnter: (to, from, next) => {
      const allowed_roles = ["Administrator", "Curator"];
      let expires = 0;
      let timestamp = 0;
      let user_role = "Viewer";
      
      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) next({ name: 'Login' })
      else next();
    }
  },
  {
    path: '/NewEntity',
    name: 'NewEntity',
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/curate/NewEntity.vue'),
    beforeEnter: (to, from, next) => {
      const allowed_roles = ["Administrator", "Curator"];
      let expires = 0;
      let timestamp = 0;
      let user_role = "Viewer";
      
      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) next({ name: 'Login' })
      else next();
    }
  },
  {
    path: '/Admin',
    name: 'Admin',
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/Admin.vue'),
    beforeEnter: (to, from, next) => {
      const allowed_roles = ["Administrator"];
      let expires = 0;
      let timestamp = 0;
      let user_role = "Viewer";
      
      if (localStorage.token) {
        expires = JSON.parse(localStorage.user).exp;
        user_role = JSON.parse(localStorage.user).user_role;
        timestamp = Math.floor(new Date().getTime() / 1000);
      }

      if (!localStorage.user || timestamp > expires || !allowed_roles.includes(user_role[0])) next({ name: 'Login' })
      else next();
    }
  },
  {
    path: '/Entities/:sysndd_id',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/Entity.vue')
  },
  {
    path: '/Genes/:gene_id',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/Gene.vue')
  },
  {
    path: '/Search/:search_term',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/Search.vue')
  },
  {
    path: '/API',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/API.vue')
  },
  {
    path: '/Ontology/:disease_term',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/Ontology.vue')
  }
]

const router = new VueRouter({
  mode: 'history',
  base: process.env.BASE_URL,
  routes
})

export default router
