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
    component: () => import(/* webpackChunkName: "Tables", webpackPrefetch: 1 */ '@/views/Entities.vue')
  },
  {
    path: '/Genes',
    name: 'Genes',
    component: () => import(/* webpackChunkName: "Tables", webpackPrefetch: 1 */ '@/views/Genes.vue')
  },
  {
    path: '/Phenotypes',
    name: 'Phenotypes',
    component: () => import(/* webpackChunkName: "Tables", webpackPrefetch: 1 */ '@/views/Phenotypes.vue')
  },
  {
    path: '/CurationComparisons',
    name: 'CurationComparisons',
    component: () => import(/* webpackChunkName: "Analyses", webpackPrefetch: 2 */ '@/views/CurationComparisons.vue')
  },
  {
    path: '/PhenotypeCorrelations',
    name: 'PhenotypeCorrelations',
    component: () => import(/* webpackChunkName: "Analyses", webpackPrefetch: 2 */ '@/views/PhenotypeCorrelations.vue')
  },
  {
    path: '/EntriesOverTime',
    name: 'EntriesOverTime',
    component: () => import(/* webpackChunkName: "Analyses", webpackPrefetch: 2 */ '@/views/EntriesOverTime.vue')
  },
  {
    path: '/GeneNetworks',
    name: 'GeneNetworks',
    component: () => import(/* webpackChunkName: "Analyses", webpackPrefetch: 2 */ '@/views/GeneNetworks.vue')
  },
  {
    path: '/Panels/:category_input?/:inheritance_input?',
    name: 'Panels',
    component: () => import(/* webpackChunkName: "Tables", webpackPrefetch: 1 */ '@/views/Panels.vue'),
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
    component: () => import(/* webpackChunkName: "About", webpackPrefetch: 5 */ '@/views/About.vue')
  },
  {
    path: '/Login',
    name: 'Login',
    component: () => import(/* webpackChunkName: "User", webpackPrefetch: 3 */ '@/views/Login.vue')
  },
  {
    path: '/Register',
    name: 'Register',
    component: () => import(/* webpackChunkName: "User", webpackPrefetch: 3 */ '@/views/Register.vue')
  },
  {
    path: '/User',
    name: 'User',
    component: () => import(/* webpackChunkName: "User", webpackPrefetch: 3 */ '@/views/User.vue')
  },
  {
    path: '/PasswordReset/:request_jwt?',
    name: 'PasswordReset',
    component: () => import(/* webpackChunkName: "User", webpackPrefetch: 3 */ '@/views/PasswordReset.vue')
  },
  {
    path: '/Review',
    name: 'Review',
    component: () => import(/* webpackChunkName: "DataEntry", webpackPrefetch: 4 */ '@/views/Review.vue'),
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
    path: '/CreateEntity',
    name: 'CreateEntity',
    component: () => import(/* webpackChunkName: "DataEntry", webpackPrefetch: 4 */ '@/views/curate/CreateEntity.vue'),
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
    path: '/ModifyEntity',
    name: 'ModifyEntity',
    component: () => import(/* webpackChunkName: "DataEntry", webpackPrefetch: 4 */ '@/views/curate/ModifyEntity.vue'),
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
    path: '/ApproveReview',
    name: 'ApproveReview',
    component: () => import(/* webpackChunkName: "DataEntry", webpackPrefetch: 4 */ '@/views/curate/ApproveReview.vue'),
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
    path: '/ApproveStatus',
    name: 'ApproveStatus',
    component: () => import(/* webpackChunkName: "DataEntry", webpackPrefetch: 4 */ '@/views/curate/ApproveStatus.vue'),
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
    path: '/ApproveUser',
    name: 'ApproveUser',
    component: () => import(/* webpackChunkName: "DataEntry", webpackPrefetch: 4 */ '@/views/curate/ApproveUser.vue'),
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
    path: '/ManageReReview',
    name: 'ManageReReview',
    component: () => import(/* webpackChunkName: "DataEntry", webpackPrefetch: 4 */ '@/views/curate/ManageReReview.vue'),
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
    component: () => import(/* webpackChunkName: "DataEntry", webpackPrefetch: 4 */ '@/views/Admin.vue'),
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
    component: () => import(/* webpackChunkName: "Pages", webpackPrefetch: 2 */ '@/views/Entity.vue')
  },
  {
    path: '/Genes/:gene_id',
    component: () => import(/* webpackChunkName: "Pages", webpackPrefetch: 2 */ '@/views/Gene.vue')
  },
  {
    path: '/Search/:search_term',
    component: () => import(/* webpackChunkName: "Pages", webpackPrefetch: 2 */ '@/views/Search.vue')
  },
  {
    path: '/API',
    component: () => import(/* webpackChunkName: "Pages", webpackPrefetch: 2 */ '@/views/API.vue')
  },
  {
    path: '/Ontology/:disease_term',
    component: () => import(/* webpackChunkName: "Pages", webpackPrefetch: 2 */ '@/views/Ontology.vue')
  }
]

const router = new VueRouter({
  mode: 'history',
  base: process.env.BASE_URL,
  routes
})

export default router
