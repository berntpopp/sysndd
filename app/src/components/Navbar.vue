<template>
  <div>
    <b-navbar
      toggleable="lg"
      type="dark"
      variant="dark"
      fixed="top"
      class="py-0 bg-navbar"
    >
      <b-navbar-brand
        to="/"
        class="py-0"
      >
        <div class="brand-container">
          <img
            src="/SysNDD_brain-dna-magnifying-glass_dall-e_logo.webp"
            height="68"
            width="68"
            alt="SysNDD Logo"
            rel="preload"
            class="app-logo"
          >
          <div class="brand-text">
            <div class="app-name">
              SysNDD
            </div>
            <div class="version-display">
              v{{ appVersion }}
            </div>
          </div>
        </div>
      </b-navbar-brand>

      <b-navbar-toggle target="nav-collapse" />

      <b-collapse
        id="nav-collapse"
        is-nav
      >
        <!-- Left aligned nav items -->
        <b-navbar-nav>
          <IconPairDropdownMenu
            v-for="(item, index) in dropdownItemsLeft"
            :key="index.id"
            :title="item.title"
            :align="item.align"
            :required="item.required"
            :items="item.items"
          />
        </b-navbar-nav>
        <!-- Left aligned nav items -->

        <b-navbar-nav
          v-if="show_search"
          class="mx-auto"
        >
          <!-- The SearchBar component -->
          <SearchBar
            placeholder-string="..."
            :in-navbar="true"
          />
          <!-- The SearchBar component -->
        </b-navbar-nav>

        <!-- Right aligned nav items -->
        <b-navbar-nav
          v-if="user"
          class="ml-auto"
        >
          <IconPairDropdownMenu
            v-for="(item, index) in dropdownItemsRightDisplay"
            :key="index.id"
            :title="item.title"
            :required="item.required"
            :align="item.align"
            :items="item.items"
          />
        </b-navbar-nav>
        <b-nav-item
          v-else
          to="/Login"
          class="ml-auto"
        >
          Login
        </b-nav-item>
        <!-- Right aligned nav items -->
      </b-collapse>
    </b-navbar>
  </div>
</template>

<script>
// Importing URLs from a constants file to avoid hardcoding them in this component
import MAIN_NAV_CONSTANTS from '@/assets/js/constants/main_nav_constants';

// Importing URLs from a constants file to avoid hardcoding them in this component
import URLS from '@/assets/js/constants/url_constants';

// Importing URLs from a constants file to avoid hardcoding them in this component
import ROLES from '@/assets/js/constants/role_constants';

import toastMixin from '@/assets/js/mixins/toastMixin';

// Importing the package.json file to get the version number
import packageInfo from '../../package.json';

// Importing the appConfig file to get the version number
import appConfig from '../config/appConfig.json';

/**
 * Navigation bar component for the SysNDD web application.
 * It provides links for navigation, user authentication status,
 * and displays the current application version.
 */
export default {
  name: 'Navbar',
  mixins: [toastMixin],
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
    };
  },
  computed: {
    /**
     * Computes the items to be displayed in the right-side dropdown menu.
     * Filters based on the user's roles and permissions.
     * @returns {Array} Filtered dropdown items.
     */
    dropdownItemsRightDisplay() {
      return this.dropdownItemsRight.map((item) => {
        if (item.id === 'user_dropdown') {
          return {
            ...item,
            title: this.user,
          };
        }
        return item;
      }).filter((i) => i.required.every((condition) => this.userAllowence[condition]));
    },
  },
  watch: {
    // used to refresh navbar on login push
    $route(to, from) {
      if (to !== from) {
        this.isUserLoggedIn();
      }
      this.$router.onReady(
        () => { (this.show_search = this.$route.name !== 'Home'); },
      );
    },
  },
  mounted() {
    this.isUserLoggedIn();
  },
  methods: {
    /**
     * Checks if user is logged in by verifying the presence of user and token in local storage.
     */
    isUserLoggedIn() {
      if (localStorage.user && localStorage.token) {
        this.checkSigninWithJWT();
      } else {
        localStorage.removeItem('user');
        localStorage.removeItem('token');
        this.user = null;
        this.userAllowence = {
          view: false,
          review: false,
          curate: false,
          admin: false,
        };
      }
    },
    /**
     * Verifies user sign-in status with JWT from local storage, and updates user permissions.
     */
    async checkSigninWithJWT() {
      const apiAuthenticateURL = `${URLS.API_URL}/api/auth/signin`;

      try {
        const response_signin = await this.axios.get(apiAuthenticateURL, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });

        this.user_from_jwt = response_signin.data;
      } catch (e) {
        localStorage.removeItem('user');
        localStorage.removeItem('token');
        this.makeToast(e, 'Error', 'danger');
      }

      if (
        this.user_from_jwt.user_name[0]
        === JSON.parse(localStorage.user).user_name[0]
      ) {
        let rest;
        [this.user, ...rest] = JSON.parse(localStorage.user).user_name;

        const user_role = JSON.parse(localStorage.user).user_role[0];
        const allowence = ROLES.ALLOWENCE_NAVIGATION[ROLES.ALLOWED_ROLES.indexOf(user_role)];

        this.userAllowence.view = allowence.includes('View');
        this.userAllowence.review = allowence.includes('Review');
        this.userAllowence.curate = allowence.includes('Curate');
        this.userAllowence.admin = allowence.includes('Admin');
      } else {
        localStorage.removeItem('user');
        localStorage.removeItem('token');
      }
    },
  },
};
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
/* Keyframe animations for logo appearance */
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes pulse {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.1); }
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
  width: 220px;
}
:deep(.dropdown-item:hover) {
  background-color: #999 !important;
  color: #000 !important;
}
.bg-navbar {
  background-image: linear-gradient(to right, #434343 0%, black 100%);
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
