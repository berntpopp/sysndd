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
      <i v-for="(icon, iconIndex) in item.icons" :key="iconIndex" :class="'bi bi-' + icon" />
      {{ item.text }}
      <component :is="item.component" v-if="item.component" />
    </BDropdownItem>
  </BNavItemDropdown>
</template>

<script>
import { apiClient } from '@/api/client';
import { useAuth } from '@/composables/useAuth';
import useToast from '@/composables/useToast';

export default {
  name: 'IconPairDropdownMenu',
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
  setup() {
    const { makeToast } = useToast();
    // v11.0 closeout F2b: auth state and token lifecycle flow through the
    // `useAuth()` composable. Previously this component read/wrote the
    // `token`/`user` localStorage keys directly and duplicated the logout
    // branch that `useAuth().logout()` now owns.
    const auth = useAuth();
    return { makeToast, auth };
  },
  methods: {
    handleItemClick(item) {
      if (item.action) {
        this[item.action]();
      }
    },
    doUserLogOut() {
      // v11.0 closeout F2b: route through `useAuth().logout()` — the
      // composable owns both localStorage keys and the reactive refs, so
      // sibling components (navbar badges, route guards) see the logout
      // immediately on the next tick.
      if (this.auth.isAuthenticated.value) {
        this.auth.logout();
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
      try {
        // `useAuth().refresh()` delegates to `api/auth.refresh`, updates
        // the reactive token + localStorage, and returns the bare JWT. The
        // `apiClient` request interceptor picks up the new token on the
        // next outbound call (the subsequent `signinWithJWT`).
        await this.auth.refresh();
        await this.signinWithJWT();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async signinWithJWT() {
      try {
        // `apiClient.get` auto-injects the Bearer header from the reactive
        // `useAuth().token`. `login(token, user)` persists the user
        // payload alongside the current token so route guards and badges
        // see the updated profile without a page reload.
        const user = await apiClient.get('/api/auth/signin');
        const currentToken = this.auth.token.value;
        if (currentToken) {
          this.auth.login(currentToken, user);
        }
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
