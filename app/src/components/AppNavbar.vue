<!-- src/components/AppNavbar.vue -->
<template>
  <div class="app-navbar">
    <BNavbar
      toggleable="lg"
      type="light"
      variant="light"
      fixed="top"
      class="app-navbar__bar bg-navbar"
    >
      <BNavbarBrand to="/" class="app-navbar__brand">
        <div class="brand-container brand-container--compact">
          <img
            src="/SysNDD_brain-dna-magnifying-glass_dall-e_logo.webp"
            height="44"
            width="44"
            alt="SysNDD Logo"
            rel="preload"
            class="app-logo"
          />
          <div class="brand-text">
            <div class="app-name">SysNDD</div>
            <div class="version-display">v{{ appVersion }}</div>
          </div>
        </div>
      </BNavbarBrand>

      <BNavbarToggle
        target="nav-collapse"
        class="app-navbar__toggle"
        aria-label="Open navigation menu"
        :aria-expanded="navbarCollapsed ? 'true' : 'false'"
      />

      <BCollapse id="nav-collapse" v-model="navbarCollapsed" is-nav>
        <!-- Left aligned nav items -->
        <BNavbarNav class="app-navbar__menus">
          <IconPairDropdownMenu
            v-for="(item, index) in dropdownItemsLeft"
            :key="index"
            :title="item.title"
            :align="item.align"
            :required="item.required"
            :items="item.items"
          />
        </BNavbarNav>
        <!-- Left aligned nav items -->

        <!-- Center aligned search bar -->
        <ul v-if="show_search" class="navbar-nav app-navbar__search mx-auto d-none d-lg-flex">
          <li class="nav-item navbar-search-item">
            <SearchCombobox placeholder-string="..." :in-navbar="true" />
          </li>
        </ul>
        <!-- Center aligned search bar -->

        <!-- Right aligned nav items -->
        <BNavbarNav v-if="user" class="app-navbar__account ms-auto">
          <IconPairDropdownMenu
            v-for="(item, index) in dropdownItemsRightDisplay"
            :key="index"
            :title="item.title"
            :align="item.align"
            :required="item.required"
            :items="item.items"
          />
        </BNavbarNav>
        <!-- Wrap Login button in ul for proper structure -->
        <ul v-else class="navbar-nav app-navbar__account ms-auto">
          <BNavItem to="/Login" class="app-navbar__login">Login</BNavItem>
        </ul>
        <!-- Right aligned nav items -->

        <!-- Mobile search bar -->
        <ul v-if="show_search" class="navbar-nav app-navbar__mobile-search d-lg-none ms-auto">
          <li class="nav-item navbar-search-item">
            <SearchCombobox placeholder-string="..." :in-navbar="true" />
          </li>
        </ul>
        <!-- Mobile search bar -->
      </BCollapse>
    </BNavbar>
  </div>
</template>

<script>
import MAIN_NAV_CONSTANTS from '@/assets/js/constants/main_nav_constants';
import ROLES from '@/assets/js/constants/role_constants';
import packageInfo from '../../package.json';
import SearchCombobox from '@/components/small/SearchCombobox.vue';
import IconPairDropdownMenu from '@/components/small/IconPairDropdownMenu.vue';
import { useAuth } from '@/composables/useAuth';
import { signin } from '@/api/auth';

export default {
  name: 'AppNavbar',
  components: {
    SearchCombobox,
    IconPairDropdownMenu,
  },
  setup() {
    // Phase E.E7: route all auth-state reads through the shared composable
    // instead of reaching into localStorage. The Bearer header is already
    // set by `@/plugins/axios` whenever `useAuth` mutates the token, so the
    // navbar no longer has to read `localStorage.getItem('token')` itself.
    const auth = useAuth();
    return { auth };
  },
  data() {
    return {
      dropdownItemsLeft: MAIN_NAV_CONSTANTS.DROPDOWN_ITEMS_LEFT,
      dropdownItemsRight: MAIN_NAV_CONSTANTS.DROPDOWN_ITEMS_RIGHT,
      user: null,
      userAllowence: {
        view: false,
        review: false,
        curate: false,
        admin: false,
      },
      user_from_jwt: [],
      show_search: false,
      appVersion: packageInfo.version,
      fetchError: false,
      navbarCollapsed: false,
    };
  },
  computed: {
    authIsAuthenticated() {
      return this.auth.isAuthenticated.value;
    },
    authUser() {
      return this.auth.user.value;
    },
    dropdownItemsRightDisplay() {
      return this.dropdownItemsRight
        .map((item) => {
          if (item.id === 'user_dropdown') {
            return {
              ...item,
              title: this.user,
            };
          }
          return item;
        })
        .filter((i) => i.required.every((condition) => this.userAllowence[condition]));
    },
  },
  watch: {
    authIsAuthenticated(isAuthenticated) {
      if (isAuthenticated) {
        this.setUserFromAuthPayload();
      } else {
        this.clearUserDisplayData();
      }
    },
    authUser: {
      handler(user) {
        if (user) {
          this.setUserFromAuthPayload();
        } else {
          this.clearUserDisplayData();
        }
      },
      deep: true,
    },
    $route(to, from) {
      if (to !== from) {
        this.isUserLoggedIn();
        // Close mobile navbar on route change (fixes #94)
        this.navbarCollapsed = false;
      }
      this.updateSearchVisibility();
    },
  },
  mounted() {
    this.isUserLoggedIn();
    this.updateSearchVisibility();
  },
  methods: {
    updateSearchVisibility() {
      // Vue Router 4: onReady replaced with isReady(). Run this on mount too
      // so direct non-home loads show the navbar search before any route change.
      this.show_search = this.$route.name !== 'Home';
      this.$router.isReady().then(() => {
        this.show_search = this.$route.name !== 'Home';
      });
    },
    isUserLoggedIn() {
      // Phase E.E7: `isAuthenticated` covers both "token present" and
      // "user payload parsed cleanly" — the composable already refused a
      // corrupt localStorage blob. No direct `localStorage.token` read.
      if (this.auth.isAuthenticated.value) {
        this.setUserFromAuthPayload();
        this.checkSigninWithJWT();
      } else {
        this.clearUserDisplayData();
      }
    },
    async checkSigninWithJWT() {
      // The `@/plugins/axios` default Authorization header is kept in
      // lockstep with `useAuth`, so we don't override it per-request here.
      try {
        this.user_from_jwt = await signin();
        this.setUserFromJWT();
      } catch (_e) {
        this.clearUserData();
      }
    },
    setUserFromJWT() {
      const authUser = this.auth.user.value;
      if (!authUser) {
        this.clearUserData();
        return;
      }
      if (this.user_from_jwt.user_name[0] === authUser.user_name[0]) {
        this.setUserFromAuthPayload();
      } else {
        this.clearUserData();
      }
    },
    setUserFromAuthPayload() {
      const authUser = this.auth.user.value;
      const user = authUser?.user_name?.[0];
      const userRole = authUser?.user_role?.[0];
      const allowence = ROLES.ALLOWENCE_NAVIGATION[ROLES.ALLOWED_ROLES.indexOf(userRole)] || [];

      if (!user || !userRole) {
        this.clearUserData();
        return;
      }

      this.user = user;
      this.userAllowence = {
        view: allowence.includes('View'),
        review: allowence.includes('Review'),
        curate: allowence.includes('Curate'),
        admin: allowence.includes('Admin'),
      };
    },
    clearUserData() {
      // Delegates the localStorage + axios-header cleanup to useAuth so the
      // navbar never touches those keys directly.
      this.auth.logout();
      this.clearUserDisplayData();
    },
    clearUserDisplayData() {
      this.user = null;
      this.userAllowence = {
        view: false,
        review: false,
        curate: false,
        admin: false,
      };
    },
  },
};
</script>

<style scoped>
.app-navbar__bar {
  z-index: 1040;
  min-height: 60px;
  padding: 0.4rem 1rem;
  border-bottom: 1px solid #d9e1ec;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 10px 28px rgba(30, 41, 59, 0.08);
  backdrop-filter: blur(12px);
}

.bg-navbar {
  background-image: none;
}

.app-navbar__brand {
  padding: 0;
  margin-right: 1.15rem;
}

.brand-container {
  display: flex;
  align-items: center;
}

.brand-container--compact {
  gap: 0.55rem;
}

.app-logo {
  display: block;
  width: 44px;
  height: 44px;
  padding: 0.15rem;
  border: 1px solid #d9e1ec;
  border-radius: 8px;
  background: #f6f8fb;
  object-fit: contain;
  transition:
    transform 0.15s ease,
    box-shadow 0.15s ease;
}

.app-logo:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 14px rgba(30, 41, 59, 0.12);
}

.brand-text {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  line-height: 1.05;
}

.app-name {
  margin: 0;
  color: #102033;
  font-size: 1.15rem;
  font-weight: 800;
}

.version-display {
  margin-top: 0.12rem;
  color: #667085;
  font-size: 0.68rem;
  font-weight: 700;
}

.app-navbar__menus {
  gap: 0.25rem;
  align-items: center;
}

:deep(.nav-link) {
  min-height: 36px;
  padding: 0.42rem 0.72rem !important;
  border-radius: 999px;
  color: #344054 !important;
  font-size: 0.92rem;
  font-weight: 700;
  transition:
    background-color 0.15s ease,
    color 0.15s ease,
    transform 0.15s ease;
}

:deep(.nav-link:hover),
:deep(.nav-link:focus-visible),
:deep(.show > .nav-link) {
  background: #eef4ff;
  color: #0d47a1 !important;
}

:deep(.nav-link:hover) {
  transform: translateY(-1px);
}

:deep(.dropdown-menu) {
  min-width: 13rem;
  padding: 0.35rem;
  border: 1px solid #d9e1ec;
  border-radius: 8px;
  background: #fff !important;
  box-shadow: 0 16px 40px rgba(16, 24, 40, 0.14);
}

:deep(.dropdown-item) {
  min-width: 0;
  padding: 0.48rem 0.65rem;
  border-radius: 6px;
  color: #1d2939 !important;
  font-size: 0.9rem;
  font-weight: 650;
}

:deep(.dropdown-item:hover),
:deep(.dropdown-item:focus-visible) {
  background: #f6f8fb !important;
  color: #0d47a1 !important;
}

.app-navbar__search {
  min-width: min(24rem, 34vw);
}

.navbar-search-item {
  margin: 0;
}

.app-navbar__account {
  align-items: center;
}

.app-navbar__login :deep(.nav-link) {
  border: 1px solid #cfd8e3;
  background: #fff;
}

/* Navbar toggler (hamburger menu) - WCAG 1.4.11 Non-text Contrast (3:1 minimum)
 * The toggler icon must be clearly visible against the dark navbar background.
 * Using bright white (#ffffff) provides excellent contrast against the dark gradient.
 */
:deep(.navbar-toggler) {
  width: 40px;
  height: 40px;
  padding: 0.45rem;
  border: 1px solid #cfd8e3;
  border-radius: 8px;
  background: #fff;

  &:focus {
    box-shadow: 0 0 0 0.2rem rgba(13, 71, 161, 0.16);
    outline: none;
  }

  &:hover {
    border-color: #9fb3c8;
    background-color: #f6f8fb;
  }
}

/* Override Bootstrap's navbar-toggler-icon for better visibility
 * The default SVG uses rgba(255,255,255,0.55) which fails WCAG contrast.
 * Using solid white (#ffffff) ensures 3:1+ contrast against dark backgrounds.
 */
:deep(.navbar-toggler-icon) {
  width: 1.25em;
  height: 1.25em;
  background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 30 30'%3e%3cpath stroke='%23344054' stroke-linecap='round' stroke-miterlimit='10' stroke-width='2.25' d='M4 7h22M4 15h22M4 23h22'/%3e%3c/svg%3e");
}

@media (max-width: 991.98px) {
  .app-navbar__bar {
    padding-right: 0.75rem;
    padding-left: 0.75rem;
  }

  :deep(.navbar-collapse) {
    position: absolute;
    top: calc(100% + 0.35rem);
    right: 0.75rem;
    left: 0.75rem;
    z-index: 1050;
    padding: 0.55rem;
    border: 1px solid #d9e1ec;
    border-radius: 8px;
    background: #fff;
    box-shadow: 0 16px 40px rgba(16, 24, 40, 0.14);
  }

  .app-navbar__menus,
  .app-navbar__account,
  .app-navbar__mobile-search {
    gap: 0.25rem;
    align-items: stretch;
  }

  :deep(.nav-link) {
    justify-content: flex-start;
    width: 100%;
    border-radius: 6px;
  }

  .app-navbar__mobile-search {
    margin-top: 0.35rem;
  }
}

@media (max-width: 420px) {
  .brand-container--compact {
    gap: 0.45rem;
  }

  .app-logo {
    width: 40px;
    height: 40px;
  }

  .app-name {
    font-size: 1rem;
  }

  .version-display {
    font-size: 0.62rem;
  }
}

@media (prefers-reduced-motion: reduce) {
  .app-logo,
  :deep(.nav-link) {
    transition: none;
  }

  .app-logo:hover,
  :deep(.nav-link:hover) {
    transform: none;
  }
}
</style>
