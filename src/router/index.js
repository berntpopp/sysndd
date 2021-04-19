import Vue from 'vue'
import VueRouter from 'vue-router'
import Home from '../views/Home.vue'
import Entities from '../views/Entities.vue'
import Genes from '../views/Genes.vue'
import Comparisons from '../views/Comparisons.vue'
import About from '../views/About.vue'
import Login from '../views/Login.vue'

import Entity from '../views/Entity.vue'

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
    path: '/Entities/:sysndd_id',
    component: Entity
  }
]

const router = new VueRouter({
  mode: 'history',
  base: process.env.BASE_URL,
  routes
})

export default router
