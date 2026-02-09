<!-- src/components/AppNavbar.vue -->
<template>
  <div>
    <BNavbar toggleable="lg" type="dark" variant="dark" fixed="top" class="py-0 bg-navbar">
      <BNavbarBrand to="/" class="py-0">
        <div class="brand-container">
          <img
            src="/SysNDD_brain-dna-magnifying-glass_dall-e_logo.webp"
            height="68"
            width="68"
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

      <BNavbarToggle target="nav-collapse" />

      <BCollapse id="nav-collapse" v-model="navbarCollapsed" is-nav>
        <!-- Left aligned nav items -->
        <BNavbarNav>
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
        <BNavbarNav v-if="show_search" class="mx-auto d-none d-lg-flex">
          <SearchCombobox placeholder-string="..." :in-navbar="true" />
        </BNavbarNav>
        <!-- Center aligned search bar -->

        <!-- Right aligned nav items -->
        <BNavbarNav v-if="user" class="ms-auto">
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
        <ul v-else class="navbar-nav ms-auto">
          <BNavItem to="/Login"> Login </BNavItem>
        </ul>
        <!-- Right aligned nav items -->

        <!-- Mobile search bar -->
        <BNavbarNav v-if="show_search" class="d-lg-none ms-auto">
          <SearchCombobox placeholder-string="..." :in-navbar="true" />
        </BNavbarNav>
        <!-- Mobile search bar -->
      </BCollapse>
    </BNavbar>
  </div>
</template>

<script>
import MAIN_NAV_CONSTANTS from '@/assets/js/constants/main_nav_constants';
import URLS from '@/assets/js/constants/url_constants';
import ROLES from '@/assets/js/constants/role_constants';
import packageInfo from '../../package.json';
import SearchCombobox from '@/components/small/SearchCombobox.vue';
import IconPairDropdownMenu from '@/components/small/IconPairDropdownMenu.vue';

export default {
  name: 'AppNavbar',
  components: {
    SearchCombobox,
    IconPairDropdownMenu,
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
    $route(to, from) {
      if (to !== from) {
        this.isUserLoggedIn();
        // Close mobile navbar on route change (fixes #94)
        this.navbarCollapsed = false;
      }
      // Vue Router 4: onReady replaced with isReady()
      this.$router.isReady().then(() => {
        this.show_search = this.$route.name !== 'Home';
      });
    },
  },
  mounted() {
    this.isUserLoggedIn();
  },
  methods: {
    isUserLoggedIn() {
      if (localStorage.user && localStorage.token) {
        this.checkSigninWithJWT();
      } else {
        this.clearUserData();
      }
    },
    async checkSigninWithJWT() {
      const apiAuthenticateURL = `${URLS.API_URL}/api/auth/signin`;

      try {
        const response_signin = await this.axios.get(apiAuthenticateURL, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });

        this.user_from_jwt = response_signin.data;
        this.setUserFromJWT();
      } catch (_e) {
        this.clearUserData();
      }
    },
    setUserFromJWT() {
      const localStorageUser = JSON.parse(localStorage.user);
      if (this.user_from_jwt.user_name[0] === localStorageUser.user_name[0]) {
        const [user] = localStorageUser.user_name;
        this.user = user;

        const user_role = localStorageUser.user_role[0];
        const allowence = ROLES.ALLOWENCE_NAVIGATION[ROLES.ALLOWED_ROLES.indexOf(user_role)];

        this.userAllowence = {
          view: allowence.includes('View'),
          review: allowence.includes('Review'),
          curate: allowence.includes('Curate'),
          admin: allowence.includes('Admin'),
        };
      } else {
        this.clearUserData();
      }
    },
    clearUserData() {
      localStorage.removeItem('user');
      localStorage.removeItem('token');
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
/* Keyframe animations for logo appearance */
@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

@keyframes pulse {
  0%,
  100% {
    transform: scale(1);
  }
  50% {
    transform: scale(1.1);
  }
}

/* Logo styles with animation */
.app-logo {
  max-width: 92px; /* Fixed maximum width */
  margin-right: 20px; /* Spacing between logo and title */
  animation: fadeIn 2s ease-out forwards;
}
.app-logo:hover {
  animation: pulse 2s infinite;
}

/* Styles for the navbar */
h3 {
  margin: 40px 0 0;
}
ul {
  list-style-type: none;
  padding: 0;
}
li {
  display: inline-block;
  margin: 0 10px;
}
a {
  color: #42b983;
}
:deep(.nav-link) {
  color: #fff !important;
}
:deep(.nav-link:hover) {
  color: #bbb !important;
}
:deep(.dropdown-menu) {
  background-color: #343a40 !important;
  color: #fff !important;
}
:deep(.dropdown-item) {
  color: #fff !important;
  min-width: 220px;
}
:deep(.dropdown-item:hover) {
  background-color: #999 !important;
  color: #000 !important;
}
.bg-navbar {
  background-image: linear-gradient(to right, #434343 0%, black 100%);
}

/* Navbar toggler (hamburger menu) - WCAG 1.4.11 Non-text Contrast (3:1 minimum)
 * The toggler icon must be clearly visible against the dark navbar background.
 * Using bright white (#ffffff) provides excellent contrast against the dark gradient.
 */
:deep(.navbar-toggler) {
  border: 2px solid rgba(255, 255, 255, 0.8);
  padding: 0.5rem;
  border-radius: 4px;

  &:focus {
    box-shadow: 0 0 0 0.25rem rgba(255, 255, 255, 0.25);
    outline: none;
  }

  &:hover {
    border-color: #ffffff;
    background-color: rgba(255, 255, 255, 0.1);
  }
}

/* Override Bootstrap's navbar-toggler-icon for better visibility
 * The default SVG uses rgba(255,255,255,0.55) which fails WCAG contrast.
 * Using solid white (#ffffff) ensures 3:1+ contrast against dark backgrounds.
 */
:deep(.navbar-toggler-icon) {
  background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 30 30'%3e%3cpath stroke='%23ffffff' stroke-linecap='round' stroke-miterlimit='10' stroke-width='2' d='M4 7h22M4 15h22M4 23h22'/%3e%3c/svg%3e");
  width: 1.5em;
  height: 1.5em;
}

/* Styles specific to the brand container in the navbar */
.brand-container {
  display: flex;
  align-items: center;
}

/* Container for the application name and version information */
.brand-text {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  padding-left: 10px; /* Adjust spacing between logo and text as needed */
}

/* Styling for the application name */
.app-name {
  font-size: 1.5rem; /* Adjust the size as needed */
  color: #ffffff; /* Adjust the color as needed */
  margin-bottom: 0.25rem; /* Adjust spacing between app name and version as needed */
}

/* Styling for displaying the application version */
.version-display {
  color: #fff;
  font-size: 0.75rem; /* Adjust the size as needed */
  margin-top: -10px; /* Decrease the top margin to bring it closer to the app name */
}
</style>
