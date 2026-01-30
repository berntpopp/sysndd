<!-- views/analyses/PubtatorNDD.vue -->
<template>
  <div class="container-fluid bg-gradient">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <BCard title="PubTator Analysis" no-body>
            <!-- Tabs in the Card Header -->
            <BCardHeader header-tag="nav">
              <BNav card-header tabs>
                <!-- Example tabs: Table, Genes, Stats, etc. -->
                <BNavItem :to="{ name: 'PubtatorNDDTable' }" exact exact-active-class="active">
                  Table
                </BNavItem>

                <BNavItem :to="{ name: 'PubtatorNDDGenes' }" exact exact-active-class="active">
                  Genes
                </BNavItem>

                <BNavItem :to="{ name: 'PubtatorNDDStats' }" exact exact-active-class="active">
                  Stats
                </BNavItem>
              </BNav>
            </BCardHeader>

            <!-- Child route content rendered here -->
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
