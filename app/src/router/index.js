import Vue from 'vue'
import VueRouter from 'vue-router'
import Home from '../views/Home.vue'
import Entities from '../views/Entities.vue'
import Genes from '../views/Genes.vue'
import Phenotypes from '../views/Phenotypes.vue'
import Comparisons from '../views/Comparisons.vue'
import About from '../views/About.vue'
import Login from '../views/Login.vue'
import User from '../views/User.vue'
import Review from '../views/Review.vue'
import Curate from '../views/Curate.vue'
import Admin from '../views/Admin.vue'
import Panels from '../views/Panels.vue'
import Ontology from '../views/Ontology.vue'

import Entity from '../views/Entity.vue'
import Gene from '../views/Gene.vue'
import Search from '../views/Search.vue'
import API from '../views/API.vue'

Vue.use(VueRouter)

const routes = [
  {
    path: '/',
    name: 'Home',
    component: Home
  },
  {
    path: '/Entities',
    name: 'Entities',
    component: Entities
  },
  {
    path: '/Genes',
    name: 'Genes',
    component: Genes
  },
  {
    path: '/Phenotypes',
    name: 'Phenotypes',
    component: Phenotypes
  },
  {
    path: '/Comparisons',
    name: 'Comparisons',
    component: Comparisons
  },
  {
    path: '/Panels',
    name: 'Panels',
    component: Panels
  },
  {
    path: '/About',
    name: 'About',
    component: About
  },
  {
    path: '/Login',
    name: 'Login',
    component: Login
  },
  {
    path: '/User',
    name: 'User',
    component: User
  },
  {
    path: '/Review',
    name: 'Review',
    component: Review,
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
      else next()
    }
  },
  {
    path: '/Curate',
    name: 'Curate',
    component: Curate,
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
      else next()
    }
  },
  {
    path: '/Admin',
    name: 'Admin',
    component: Admin,
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
      else next()
    }
  },
  {
    path: '/Entities/:sysndd_id',
    component: Entity
  },
  {
    path: '/Genes/:hgnc_id',
    component: Gene
  },
  {
    path: '/Search/:search_term',
    component: Search
  },
  {
    path: '/API',
    component: API
  },
  {
    path: '/Ontology/:disease_ontology_id',
    component: Ontology
  }
]

const router = new VueRouter({
  mode: 'history',
  base: process.env.BASE_URL,
  routes
})

export default router
