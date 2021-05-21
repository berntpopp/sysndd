<template>
  <div style="padding-top: 80px;">
    <h3>This is an about page</h3>

      <b-card-text class="text-left">
        The SysNDD database contains gene disease relationships manually curated from the literature based on the previous curation effort in SysID.
        Our long-term goal is incorporation of the SysNDD/SysID data into other gene disease relationship databases like the Orphanet ontology.
        To allow interoperability and mapping between gene-, phenotype- or disease-oriented databases we center our approach around curated gene-inheritance-disease units, so called entities, 
        which are annotated with a predefined list of NDD associated phenotypes.
      </b-card-text>

  </div>
</template>

<script>
export default {
  name: 'About',
}
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
</style>
