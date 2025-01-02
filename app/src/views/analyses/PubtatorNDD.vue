<!-- views/analyses/PubtatorNDD.vue -->
<template>
  <div class="container-fluid bg-gradient">
    <b-container fluid>
      <b-row class="justify-content-md-center py-2">
        <b-col md="12">
          <b-card
            title="PubTator Analysis"
            no-body
          >
            <!-- Tabs in the Card Header -->
            <b-card-header header-tag="nav">
              <b-nav
                card-header
                tabs
              >
                <!-- Example tabs: Table, Genes, Stats, etc. -->
                <b-nav-item
                  :to="{ name: 'PubtatorNDDTable' }"
                  exact
                  exact-active-class="active"
                >
                  Table
                </b-nav-item>

                <b-nav-item
                  :to="{ name: 'PubtatorNDDGenes' }"
                  exact
                  exact-active-class="active"
                >
                  Genes
                </b-nav-item>

                <b-nav-item
                  :to="{ name: 'PubtatorNDDStats' }"
                  exact
                  exact-active-class="active"
                >
                  Stats
                </b-nav-item>
              </b-nav>
            </b-card-header>

            <!-- Child route content rendered here -->
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
  name: 'PubtatorNDDParent',
  // purely manages the nav tabs + route display
};
</script>

<style scoped>
/* Optional styling for background gradient, spacing, etc. */
.bg-gradient {
  background: linear-gradient(120deg, #f8f9fa 0%, #fafbfc 100%);
}
</style>
