import Vue from 'vue'
import VueRouter from 'vue-router'

Vue.use(VueRouter)

const routes = [
  {
    path: '/',
    name: 'Home',
    component: () => import(/* webpackChunkName: "Home", webpackPrefetch: 1 */ '@/views/Home.vue')
  },
  {
    path: '/Entities',
    name: 'Entities',
    component: () => import(/* webpackChunkName: "Tables"*/ '@/views/tables/Entities.vue')
  },
  {
    path: '/Genes',
    name: 'Genes',
    component: () => import(/* webpackChunkName: "Tables" */ '@/views/tables/Genes.vue')
  },
  {
    path: '/Phenotypes',
    name: 'Phenotypes',
    component: () => import(/* webpackChunkName: "Tables" */ '@/views/tables/Phenotypes.vue')
  },
  {
    path: '/CurationComparisons',
    name: 'CurationComparisons',
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/analyses/CurationComparisons.vue')
  },
  {
    path: '/PhenotypeCorrelations',
    name: 'PhenotypeCorrelations',
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/analyses/PhenotypeCorrelations.vue')
  },
  {
    path: '/EntriesOverTime',
    name: 'EntriesOverTime',
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/analyses/EntriesOverTime.vue')
  },
  {
    path: '/PublicationsNDD',
    name: 'PublicationsNDD',
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/analyses/PublicationsNDD.vue')
  },
  {
    path: '/GeneNetworks',
    name: 'GeneNetworks',
    component: () => import(/* webpackChunkName: "Analyses" */ '@/views/analyses/GeneNetworks.vue')
  },
  {
    path: '/Panels/:category_input?/:inheritance_input?',
    name: 'Panels',
    component: () => import(/* webpackChunkName: "Tables" */ '@/views/tables/Panels.vue'),
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
    path: '/CreateEntity',
    name: 'CreateEntity',
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/curate/CreateEntity.vue'),
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
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/curate/ModifyEntity.vue'),
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
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/curate/ApproveReview.vue'),
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
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/curate/ApproveStatus.vue'),
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
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/curate/ApproveUser.vue'),
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
    component: () => import(/* webpackChunkName: "DataEntry" */ '@/views/curate/ManageReReview.vue'),
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
    path: '/ManageUser',
    name: 'ManageUser',
    component: () => import(/* webpackChunkName: "Administration" */ '@/views/admin/ManageUser.vue'),
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
    path: '/ManageAnnotations',
    name: 'ManageAnnotations',
    component: () => import(/* webpackChunkName: "Administration" */ '@/views/admin/ManageAnnotations.vue'),
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
    path: '/ManageAbout',
    name: 'ManageAbout',
    component: () => import(/* webpackChunkName: "Administration" */ '@/views/admin/ManageAbout.vue'),
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
    name: 'Entity',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/pages/Entity.vue')
  },
  {
    path: '/Genes/:gene_id',
    name: 'Gene',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/pages/Gene.vue')
  },
  {
    path: '/Search/:search_term',
    name: 'Search',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/pages/Search.vue')
  },
  {
    path: '/API',
    name: 'API',
    component: () => import(/* webpackChunkName: "API" */ '@/views/API.vue')
  },
  {
    path: '/Ontology/:disease_term',
    name: 'Ontology',
    component: () => import(/* webpackChunkName: "Pages" */ '@/views/pages/Ontology.vue')
  },
  { path: "*",
  component: () => import(/* webpackChunkName: "Pages" */ '@/views/PageNotFound.vue')
  },
]

const router = new VueRouter({
  mode: 'history',
  base: process.env.BASE_URL,
  routes
})

export default router
