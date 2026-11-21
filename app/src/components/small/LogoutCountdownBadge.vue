<!-- LogoutCountdownBadge.vue -->
<template>
  <BBadge variant="info">
    {{ Math.floor(time_to_logout) }}m
    {{ ((time_to_logout - Math.floor(time_to_logout)) * 60).toFixed(0) }}s
  </BBadge>
</template>

<script>
import useToast from '@/composables/useToast';
import { useAuth } from '@/composables/useAuth';

export default {
  name: 'LogoutCountdownBadge',
  setup() {
    const { makeToast } = useToast();
    // Phase E.E7: source-of-truth for token / user / expiry is now
    // `useAuth()`. The stale "TODO: move to a mixin" comments that were
    // sprinkled across this file have been deleted — the mixin they asked
    // for is, in effect, this composable.
    const auth = useAuth();
    return { makeToast, auth };
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
      if (this.auth.isAuthenticated.value) {
        this.auth.logout();

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
      // TODO: remove magic numbers and put them in constants in a config file
      const secondToMinuteDivider = 60;
      const warningTimePoints = [60, 180, 300];
      const user = this.auth.user.value;
      if (!this.auth.isAuthenticated.value || !user) {
        return;
      }

      const expires = user.exp?.[0];
      if (typeof expires !== 'number') {
        return;
      }
      const timestamp = Math.floor(Date.now() / 1000);

      if (expires > timestamp) {
        this.time_to_logout = ((expires - timestamp) / secondToMinuteDivider).toFixed(2);
        // ponytail: exact-second match can miss a point if the 1 s tick drifts; use a range if users report missed warnings.
        if (warningTimePoints.includes(expires - timestamp)) {
          const minutes = Math.round((expires - timestamp) / secondToMinuteDivider);
          this.makeToast(
            `Your session ends in ${minutes} min. Click Token in the user menu to refresh it.`,
            'Session ending soon',
            'warning'
          );
        }
      } else {
        this.doUserLogOut();
      }
    },
  },
};
</script>
