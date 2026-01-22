/* eslint-disable no-console */

import { register } from 'register-service-worker';

// Only register service worker in production mode and not in docker
// VUE_APP_MODE is set in .env files (docker mode doesn't need service worker)
const isDocker = process.env.VUE_APP_MODE === 'docker';

if (process.env.NODE_ENV === 'production' && !isDocker) {
  register(`${process.env.BASE_URL}service-worker.js`, {
    ready() {
      console.log(
        'App is being served from cache by a service worker.\n'
          + 'For more details, visit https://goo.gl/AFskqB',
      );
    },
    registered() {
      console.log('Service worker has been registered.');
    },
    cached() {
      console.log('Content has been cached for offline use.');
    },
    updatefound() {
      console.log('New content is downloading.');
    },
    updated() {
      console.log('New content is available; please refresh.');
      // added acording to https://stackoverflow.com/questions/54145735/vue-pwa-not-getting-new-content-after-refresh
      window.location.reload(true);
    },
    offline() {
      console.log(
        'No internet connection found. App is running in offline mode.',
      );
    },
    error(error) {
      console.error('Error during service worker registration:', error);
    },
  });
}

// Service worker registration in development is disabled
// as it can cause caching issues during development
