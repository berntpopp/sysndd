<!-- LogoutCountdownBadge.vue -->
<template>
  <b-badge variant="info">
    {{ Math.floor(time_to_logout) }}m
    {{
      ((time_to_logout - Math.floor(time_to_logout)) * 60).toFixed(
        0
      )
    }}s
  </b-badge>
</template>

<script>

import toastMixin from '@/assets/js/mixins/toastMixin';

export default {
  name: 'LogoutCountdownBadge',
  mixins: [toastMixin],
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
  beforeDestroy() {
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
