<!-- views/analyses/PublicationsNDD.vue -->
<template>
  <div class="container-fluid bg-gradient">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <BCard title="NDD Publications" no-body>
            <!-- Card Header with tabs -->
            <BCardHeader header-tag="nav">
              <BNav card-header tabs>
                <!-- 1) All Publications Child -->
                <BNavItem :to="{ name: 'PublicationsNDDTable' }" exact exact-active-class="active">
                  SysNDD Curated
                </BNavItem>

                <!-- 2) Time Plot Child -->
                <BNavItem
                  :to="{ name: 'PublicationsNDDTimePlot' }"
                  exact
                  exact-active-class="active"
                >
                  Time Plot
                </BNavItem>

                <!-- 3) Stats Child -->
                <BNavItem :to="{ name: 'PublicationsNDDStats' }" exact exact-active-class="active">
                  Stats
                </BNavItem>
              </BNav>
            </BCardHeader>

            <!-- Card Body where the child routes are rendered -->
            <BCardBody>
              <router-view />
            </BCardBody>
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
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
