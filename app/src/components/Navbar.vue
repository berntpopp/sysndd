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
        <img
          src="/SysNDD_brain-dna-magnifying-glass_dall-e_logo.webp"
          height="68"
          width="68"
          alt="SysNDD Logo"
          rel="preload"
        >
        SysNDD
      </b-navbar-brand>

      <b-navbar-toggle target="nav-collapse" />

      <b-collapse
        id="nav-collapse"
        is-nav
      >
        <b-navbar-nav>
          <!-- Navbar Tables dropdown -->
          <b-nav-item-dropdown text="Tables">
            <b-dropdown-item to="/Entities">
              Entities
            </b-dropdown-item>
            <b-dropdown-item to="/Genes">
              Genes
            </b-dropdown-item>
            <b-dropdown-item to="/Phenotypes">
              Phenotypes
            </b-dropdown-item>
            <b-dropdown-item to="/Panels">
              Panels
            </b-dropdown-item>
          </b-nav-item-dropdown>

          <!-- Navbar Analyses dropdown -->
          <b-nav-item-dropdown text="Analyses">
            <b-dropdown-item to="/CurationComparisons">
              Compare curations
            </b-dropdown-item>
            <b-dropdown-item to="/PhenotypeCorrelations">
              Correlate phenotypes
            </b-dropdown-item>
            <b-dropdown-item to="/EntriesOverTime">
              Entries over time
            </b-dropdown-item>
            <b-dropdown-item to="/PublicationsNDD">
              NDD Publications
            </b-dropdown-item>
            <b-dropdown-item to="/GeneNetworks">
              Functional clusters
            </b-dropdown-item>
          </b-nav-item-dropdown>

          <b-nav-item to="/About">
            About
          </b-nav-item>
        </b-navbar-nav>

        <b-navbar-nav class="mx-auto">
          <b-nav-form
            v-if="show_search"
            @submit.stop.prevent="handleSearchInputKeydown"
          >
            <b-input-group class="mb-2">
              <b-form-input
                v-model="search_input"
                list="search-list"
                type="search"
                placeholder="..."
                size="sm"
                autocomplete="off"
                class="navbar-search"
                debounce="300"
                @update="loadSearchInfo"
                @keydown.native="handleSearchInputKeydown"
              />

              <b-form-datalist
                id="search-list"
                :options="search_keys"
              />

              <b-input-group-append>
                <b-button
                  variant="outline-primary"
                  size="sm"
                  :disabled="search_input.length < 2"
                  @click="handleSearchInputKeydown"
                >
                  <b-icon icon="search" />
                </b-button>
              </b-input-group-append>
            </b-input-group>
          </b-nav-form>
        </b-navbar-nav>

        <!-- Right aligned nav items -->
        <b-navbar-nav class="ml-auto">
          <!-- Navbar Admin dropdown -->
          <b-nav-item-dropdown
            v-if="user && admin"
            text="Administration"
          >
            <b-dropdown-item to="/ManageUser">
              <b-icon
                icon="gear"
                font-scale="1.0"
              />
              <b-icon
                icon="person-circle"
                font-scale="1.0"
              />
              Manage user
            </b-dropdown-item>
            <b-dropdown-item to="/ManageAnnotations">
              <b-icon
                icon="gear"
                font-scale="1.0"
              />
              <b-icon
                icon="table"
                font-scale="1.0"
              />
              Manage annotations
            </b-dropdown-item>
            <b-dropdown-item to="/ManageAbout">
              <b-icon
                icon="gear"
                font-scale="1.0"
              />
              <b-icon
                icon="question-circle-fill"
                font-scale="1.0"
              />
              Manage about
            </b-dropdown-item>
          </b-nav-item-dropdown>
          <!-- Navbar Admin dropdown -->

          <!-- Navbar Curation dropdown -->
          <b-nav-item-dropdown
            v-if="user && curate"
            text="Curation"
          >
            <b-dropdown-item to="/CreateEntity">
              <b-icon
                icon="plus-square"
                font-scale="1.0"
              />
              <b-icon
                icon="link"
                font-scale="1.0"
              />
              Create entity
            </b-dropdown-item>
            <b-dropdown-item to="/ModifyEntity">
              <b-icon
                icon="pen"
                font-scale="1.0"
              />
              <b-icon
                icon="link"
                font-scale="1.0"
              />
              Modify entity
            </b-dropdown-item>
            <b-dropdown-item to="/ApproveReview">
              <b-icon
                icon="check"
                font-scale="1.0"
              />
              <b-icon
                icon="clipboard-plus"
                font-scale="1.0"
              />
              Approve review
            </b-dropdown-item>
            <b-dropdown-item to="/ApproveStatus">
              <b-icon
                icon="check"
                font-scale="1.0"
              />
              <b-icon
                icon="stoplights"
                font-scale="1.0"
              />
              Approve status
            </b-dropdown-item>
            <b-dropdown-item to="/ApproveUser">
              <b-icon
                icon="check"
                font-scale="1.0"
              />
              <b-icon
                icon="person-circle"
                font-scale="1.0"
              />
              Approve user
            </b-dropdown-item>
            <b-dropdown-item to="/ManageReReview">
              <b-icon
                icon="gear"
                font-scale="1.0"
              />
              <b-icon
                icon="clipboard-check"
                font-scale="1.0"
              />
              Manage re-review
            </b-dropdown-item>
          </b-nav-item-dropdown>
          <!-- Navbar Curation dropdown -->

          <b-nav-item
            v-if="user && review"
            to="/Review"
          >
            Review
          </b-nav-item>

          <b-nav-item-dropdown
            v-if="user"
            right
          >
            <!-- Using 'button-content' slot -->
            <template #button-content>
              <em>{{ user }}</em>
            </template>
            <b-dropdown-item to="/User">
              <b-icon
                icon="person-circle"
                font-scale="1.0"
              /> View profile
            </b-dropdown-item>
            <b-dropdown-item @click="refreshWithJWT">
              <b-icon
                icon="arrow-repeat"
                font-scale="1.0"
              /> Token
              <b-badge variant="info">
                {{ Math.floor(time_to_logout) }}m
                {{
                  ((time_to_logout - Math.floor(time_to_logout)) * 60).toFixed(
                    0
                  )
                }}s
              </b-badge>
            </b-dropdown-item>
            <b-dropdown-item @click="doUserLogOut">
              <b-icon
                icon="x-circle"
                font-scale="1.0"
              /> Sign out
            </b-dropdown-item>
          </b-nav-item-dropdown>
          <b-nav-item
            v-else
            to="/Login"
          >
            Login
          </b-nav-item>
        </b-navbar-nav>
      </b-collapse>
    </b-navbar>
  </div>
</template>

<script>
// Importing URLs from a constants file to avoid hardcoding them in this component
import URLS from '@/assets/js/constants/url_constants';

import toastMixin from '@/assets/js/mixins/toastMixin';

export default {
  name: 'Navbar',
  mixins: [toastMixin],
  data() {
    return {
      user: null,
      review: false,
      curate: false,
      admin: false,
      user_from_jwt: [],
      time_to_logout: 0,
      search_input: '',
      search_keys: [],
      search_object: {},
      show_search: false,
    };
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

    // set constant for interval refresh in milliseconds
    const UPDATE_INTERVAL = 1000;

    this.interval = setInterval(() => {
      this.updateDiffs();
    }, UPDATE_INTERVAL);
    this.updateDiffs();
  },
  beforeDestroy() {
    clearInterval(this.interval);
  },
  methods: {
    isUserLoggedIn() {
      if (localStorage.user && localStorage.token) {
        this.checkSigninWithJWT();
      } else {
        localStorage.removeItem('user');
        localStorage.removeItem('token');
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

        if (
          this.user_from_jwt.user_name[0]
          === JSON.parse(localStorage.user).user_name[0]
        ) {
          const allowed_roles = ['Administrator', 'Curator', 'Reviewer'];
          const allowence_navigation = [
            ['Admin', 'Curate', 'Review'],
            ['Curate', 'Review'],
            ['Review'],
          ];

          let rest;
          [this.user, ...rest] = JSON.parse(localStorage.user).user_name;

          const user_role = JSON.parse(localStorage.user).user_role[0];
          const allowence = allowence_navigation[allowed_roles.indexOf(user_role)];

          this.review = allowence.includes('Review');
          this.curate = allowence.includes('Curate');
          this.admin = allowence.includes('Admin');
        } else {
          localStorage.removeItem('user');
          localStorage.removeItem('token');
        }
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
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
    async loadSearchInfo() {
      if (this.search_input.length > 0) {
        const apiSearchURL = `${URLS.API_URL}/api/search/${this.search_input}`;
        try {
          const response_search = await this.axios.get(apiSearchURL);
          let rest;
          [this.search_object, ...rest] = response_search.data;
          this.search_keys = Object.keys(response_search.data[0]);
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
        }
      }
    },
    handleSearchInputKeydown(event) {
      if (
        ((event.which === 13) || (event.which === 1))
        && (this.search_input.length > 0)
        && !(this.search_object[this.search_input] === undefined)
      ) {
        this.$router.push(this.search_object[this.search_input][0].link);
        this.search_input = '';
      } else if (
        ((event.which === 13) || (event.which === 1))
        && (this.search_input.length > 0)
        && (this.search_object[this.search_input] === undefined)
      ) {
        this.$router.push(`/Search/${this.search_input}`);
        this.search_input = '';
      }
    },
    doUserLogOut() {
      if (localStorage.user || localStorage.token) {
        localStorage.removeItem('user');
        localStorage.removeItem('token');
        this.user = null;

        // based on https://stackoverflow.com/questions/57837758/navigationduplicated-navigating-to-current-location-search-is-not-allowed
        // to avoid double navigation
        const path = '/';
        if (this.$route.path !== path) this.$router.push({ name: 'Home' });
      }
    },
    updateDiffs() {
      const timestampMillisecondDivider = 1000;
      const secondToMinuteDivider = 60;
      const warningTimePoints = [60, 180, 300];
      if (localStorage.token) {
        const expires = JSON.parse(localStorage.user).exp;
        const timestamp = Math.floor(new Date().getTime() / timestampMillisecondDivider);

        if (expires > timestamp) {
          this.time_to_logout = ((expires - timestamp) / secondToMinuteDivider).toFixed(2);
          if (warningTimePoints.includes(expires - timestamp)) {
            this.makeToast(
              'Refresh token.',
              `Logout in ${expires - timestamp} seconds`,
              'danger',
            );
          }
        } else {
          this.doUserLogOut();
        }
      }
    },
  },
};
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
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
.navbar-search {
  width: 400px;
}
</style>
