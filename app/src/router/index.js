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

import Entity from '../views/Entity.vue'
import Gene from '../views/Gene.vue'

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
    component: Review
  },
  {
    path: '/Entities/:sysndd_id',
    component: Entity
  },
  {
    path: '/Genes/:hgnc_id',
    component: Gene
  }
]

const router = new VueRouter({
  mode: 'history',
  base: process.env.BASE_URL,
  routes
})

export default router
