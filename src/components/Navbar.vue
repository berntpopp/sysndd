<template>
  <mdb-navbar dark color="elegant">
    <mdb-navbar-brand tag="a" href="/">
      <img src="../../public/android-chrome-192x192.png" height="40" alt=""> SysNDD
    </mdb-navbar-brand>
    <mdb-navbar-toggler>
      <mdb-navbar-nav>
        <mdb-nav-item href="Entities">Entities</mdb-nav-item>
        <mdb-nav-item href="Genes">Genes</mdb-nav-item>
        <mdb-nav-item href="Comparisions">Comparisions</mdb-nav-item>
        <mdb-nav-item href="About">About</mdb-nav-item>
        <mdb-nav-item href="Login">Login</mdb-nav-item>
      </mdb-navbar-nav>
      <form>
        <mdb-input type="text" class="text-white" placeholder="Search" aria-label="Search" label navInput waves waves-fixed/>
      </form>
    </mdb-navbar-toggler>
  </mdb-navbar>
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
