<!-- views/analyses/PublicationsNDD.vue -->
<template>
  <div class="container-fluid bg-gradient">
    <b-container fluid>
      <b-row class="justify-content-md-center py-2">
        <b-col md="12">
          <b-card
            title="NDD Publications"
            no-body
          >
            <!-- Card Header with tabs -->
            <b-card-header header-tag="nav">
              <b-nav
                card-header
                tabs
              >
                <!-- 1) All Publications Child -->
                <b-nav-item
                  :to="{ name: 'PublicationsNDDTable' }"
                  exact
                  exact-active-class="active"
                >
                  All
                </b-nav-item>

                <!-- 2) Time Plot Child -->
                <b-nav-item
                  :to="{ name: 'PublicationsNDDTimePlot' }"
                  exact
                  exact-active-class="active"
                >
                  Time Plot
                </b-nav-item>

                <!-- 3) Stats Child -->
                <b-nav-item
                  :to="{ name: 'PublicationsNDDStats' }"
                  exact
                  exact-active-class="active"
                >
                  Stats
                </b-nav-item>

                <!-- 4) PubTator Child -->
                <b-nav-item
                  :to="{ name: 'PublicationsNDDPubtator' }"
                  exact
                  exact-active-class="active"
                >
                  PubTator
                </b-nav-item>
              </b-nav>
            </b-card-header>

            <!-- Card Body where the child routes are rendered -->
            <b-card-body>
              <router-view />
            </b-card-body>
          </b-card>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
export default {
  name: 'PublicationsNDDParent',
  // This parent purely handles tab navigation & route display.
};
</script>

<style scoped>
/* Optional styling for your background gradient, etc. */
</style>
