<template>
  <div class="container-fluid" style="padding-top: 80px;">
        <div class="jumbotron">
        <h1>Welcome to SysNDD!</h1>

        <p class="lead">Here we will create <i>SysNDD</i> as a successor of the <i>SysID</i> database. Please stay tuned for updates.</p>

    </div>

    <div class="body-content">

        <div class="row">
            <div class="col-lg-12">
                <h2>SysNDD</h2>

                <p>The SysNDD database will contain gene disease relationships manually curated from the literature based on the previous curation effort in SysID. <br>
                Our long-term goal is incorporation of the SysNDD/SysID data into other gene disease relationship databases like the Orphanet ontology. <br> <br>
                To allow interoperability and mapping between gene-, phenotype- or disease-oriented databases we will center our approach around curated gene-inheritance-disease units, 
                which will be annotated with a predefined list of NDD associated phenotypes. <br> <br>
                
                </p>

            </div>
        </div>

    </div>
  </div>
</template>

<script>
export default {
  name: 'Home',
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
