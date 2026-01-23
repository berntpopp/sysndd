<!-- src/components/small/IconPairDropdownMenu.vue -->
<template>
  <BNavItemDropdown
    :text="title"
    :end="align === 'right' || undefined"
    menu-class="dropdown-menu-center"
  >
    <BDropdownItem
      v-for="(item, index) in items"
      :key="index"
      :to="item.path"
      class="text-center"
      @click="handleItemClick(item)"
    >
      <i
        v-for="(icon, iconIndex) in item.icons"
        :key="iconIndex"
        :class="'bi bi-' + icon"
      />
      {{ item.text }}
      <component
        :is="item.component"
        v-if="item.component"
      />
    </BDropdownItem>
  </BNavItemDropdown>
</template>

<script>
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
    handleItemClick(item) {
      if (item.action) {
        this[item.action]();
      }
    },
    doUserLogOut() {
      if (localStorage.user || localStorage.token) {
        localStorage.removeItem('user');
        localStorage.removeItem('token');
        this.reloadHomePage();
      }
    },
    reloadHomePage() {
      const path = '/';
      if (this.$route.path !== path) {
        this.$router.push({ name: 'Home' });
      } else {
        this.$router.go();
      }
    },
    async refreshWithJWT() {
      const apiAuthenticateURL = `${URLS.API_URL}/api/auth/refresh`;
      try {
        const response = await this.axios.get(apiAuthenticateURL, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        localStorage.setItem('token', response.data[0]);
        this.signinWithJWT();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async signinWithJWT() {
      const apiAuthenticateURL = `${URLS.API_URL}/api/auth/signin`;
      try {
        const response = await this.axios.get(apiAuthenticateURL, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        localStorage.setItem('user', JSON.stringify(response.data));
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
