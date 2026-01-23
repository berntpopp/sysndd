<!-- LogoutCountdownBadge.vue -->
<template>
  <BBadge variant="info">
    {{ Math.floor(time_to_logout) }}m
    {{
      ((time_to_logout - Math.floor(time_to_logout)) * 60).toFixed(
        0
      )
    }}s
  </BBadge>
</template>

<script>
import useToast from '@/composables/useToast';

export default {
  name: 'LogoutCountdownBadge',
  setup() {
    const { makeToast } = useToast();
    return { makeToast };
  },
  data() {
    return {
      time_to_logout: 0,
    };
  },
  mounted() {
    // set constant for interval refresh in milliseconds
    const UPDATE_INTERVAL = 1000;

    this.interval = setInterval(() => {
      this.updateDiffs();
    }, UPDATE_INTERVAL);
    this.updateDiffs();
  },
  beforeUnmount() {
    clearInterval(this.interval);
  },
  methods: {
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
    // TODO: move to a mixin to be used in other components (DRY)
    async refreshWithJWT() {
      const apiAuthenticateURL = `${import.meta.env.VITE_API_URL}/api/auth/refresh`;
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
    // TODO: move to a mixin to be used in other components (DRY)
    async signinWithJWT() {
      const apiAuthenticateURL = `${import.meta.env.VITE_API_URL}/api/auth/signin`;

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
    // TODO: move to a mixin to be used in other components (DRY)
    updateDiffs() {
      // TODO: remove magic numbers and put them in constants in a config file
      const timestampMillisecondDivider = 1000;
      const secondToMinuteDivider = 60;
      const warningTimePoints = [60, 180, 300];
      if (localStorage.token) {
        const expires = JSON.parse(localStorage.user).exp;
        const timestamp = Math.floor(new Date().getTime() / timestampMillisecondDivider);

        if (expires > timestamp) {
          this.time_to_logout = ((expires - timestamp) / secondToMinuteDivider).toFixed(2);
          if (warningTimePoints.includes(expires - timestamp)) {
            // Use a shorter name for this.$createElement
            const h = this.$createElement;

            // compose the logout message
            const vNodesMsg = h(
              'p',
              { class: ['text-center', 'mb-0'] },
              [
                'Token ',
                h('b-badge', {
                  props: { variant: 'success', href: '#' },
                  // TODO: make the modal close after clicking on the badge
                  on: { click: () => this.refreshWithJWT() },
                },
                'refresh now'),
              ],
            );

            this.makeToast(
              [vNodesMsg],
              `Warning: Logout in ${expires - timestamp} seconds`,
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
