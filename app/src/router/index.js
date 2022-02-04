import Vue from 'vue'
import VueRouter from 'vue-router'

function lazyLoad(view){
  return() => import(`@/views/${view}.vue`)
}

Vue.use(VueRouter)

const routes = [
  {
    path: '/',
    name: 'Home',
    component: lazyLoad('Home')
  },
  {
    path: '/Entities',
    name: 'Entities',
    component: lazyLoad('Entities')
  },
  {
    path: '/Genes',
    name: 'Genes',
    component: lazyLoad('Genes')
  },
  {
    path: '/Phenotypes',
    name: 'Phenotypes',
    component: lazyLoad('Phenotypes')
  },
  {
    path: '/Comparisons',
    name: 'Comparisons',
    component: lazyLoad('Comparisons')
  },
  {
    path: '/Panels/:category_input?/:inheritance_input?',
    name: 'Panels',
    component: lazyLoad('Panels'),
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
    component: lazyLoad('About')
  },
  {
    path: '/Login',
    name: 'Login',
    component: lazyLoad('Login')
  },
  {
    path: '/Register',
    name: 'Register',
    component: lazyLoad('Register')
  },
  {
    path: '/User',
    name: 'User',
    component: lazyLoad('User')
  },
  {
    path: '/Review',
    name: 'Review',
    component: lazyLoad('Review'),
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
    component: lazyLoad('Curate'),
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
    component: lazyLoad('Admin'),
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
    component: lazyLoad('Entity')
  },
  {
    path: '/Genes/:gene_id',
    component: lazyLoad('Gene')
  },
  {
    path: '/Search/:search_term',
    component: lazyLoad('Search')
  },
  {
    path: '/API',
    component: lazyLoad('API')
  },
  {
    path: '/Ontology/:disease_term',
    component: lazyLoad('Ontology')
  }
]

const router = new VueRouter({
  mode: 'history',
  base: process.env.BASE_URL,
  routes
})

export default router
