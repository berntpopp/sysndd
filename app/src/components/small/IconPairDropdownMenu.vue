<template>
  <b-nav-item-dropdown
    :text="title"
    :right="align === 'right'"
    menu-class="dropdown-menu-center"
  >
    <b-dropdown-item
      v-for="(item, index) in items"
      :key="index"
      :to="item.path"
      class="text-center"
      @click="call(item)"
    >
      <b-icon
        v-for="(icon, iconIndex) in item.icons"
        :key="iconIndex"
        :icon="icon"
        font-scale="1.0"
      />
      {{ item.text }}
      <component
        :is="item.component"
        v-if="item.component"
      />
    </b-dropdown-item>
  </b-nav-item-dropdown>
</template>

<script>
// Importing URLs from a constants file to avoid hardcoding them in this component
import URLS from '@/assets/js/constants/url_constants';
import toastMixin from '@/assets/js/mixins/toastMixin';

export default {
  name: 'IconPairDropdownMenu',
  mixins: [toastMixin],
  props: {
    title: {
      type: String,
      required: true,
    },
    required: {
      type: Array,
      required: true,
    },
    align: {
      type: String,
      required: true,
    },
    items: {
      type: Array,
      required: true,
    },
  },
  methods: {
    // this method is called when a dropdown item is clicked
    // it checks if the item has an action property and if it does
    // it calls the method with the same name as the value of the action property
    call(item) {
      if (item.action) {
        this[item.action]();
      }
    },
    doUserLogOut() {
      if (localStorage.user || localStorage.token) {
        localStorage.removeItem('user');
        localStorage.removeItem('token');

        // based on https://stackoverflow.com/questions/57837758/navigationduplicated-navigating-to-current-location-search-is-not-allowed
        // to avoid double navigation
        // https://stackoverflow.com/questions/41301099/do-we-have-router-reload-in-vue-router
        const path = '/';

        if (this.$route.path !== path) {
          this.$router.push({ name: 'Home' });
        } else {
          this.$router.go();
        }
      }
    },
    async refreshWithJWT() {
      const apiAuthenticateURL = `${URLS.API_URL}/api/auth/refresh`;

      try {
        const response_refresh = await this.axios.get(apiAuthenticateURL, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });

        localStorage.setItem('token', response_refresh.data[0]);
        this.signinWithJWT();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async signinWithJWT() {
      const apiAuthenticateURL = `${URLS.API_URL}/api/auth/signin`;

      try {
        const response_signin = await this.axios.get(apiAuthenticateURL, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });

        localStorage.setItem('user', JSON.stringify(response_signin.data));
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
  },
};
</script>

<style scoped>
.dropdown-menu-center .dropdown-menu {
  text-align: center;
}

.text-center {
  text-align: center !important;
}
</style>
