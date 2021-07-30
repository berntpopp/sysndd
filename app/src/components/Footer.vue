<template>
  <div>
    <footer class="footer">
    <b-navbar toggleable="sm" type="light" variant="light" class="py-0">
      <b-navbar-toggle target="footer-collapse"></b-navbar-toggle>
        <b-collapse id="footer-collapse" is-nav>
          <b-navbar-nav justified class="flex-grow-1">
            <b-nav-item href="http://creativecommons.org/licenses/by/4.0/" target="_blank">
              <img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by/4.0/88x31.png" height="30"  />
            </b-nav-item>
            <b-nav-item href="https://github.com/berntpopp/sysndd" target="_blank">
              <img src="../../public/GitHub-Mark-64px.png" height="30" alt="" />
            </b-nav-item>
            <b-nav-item href="/API">
              <img src="../../public/swagger.svg" height="30" alt="" />
            </b-nav-item>
            <b-nav-item href="https://www.dfg.de/" target="_blank">
              <img src="../../public/dfg_logo_schriftzug_schwarz_foerderung_en.gif" height="30" alt="" />
            </b-nav-item>
            <b-nav-item href="https://www.unibe.ch/" target="_blank">
              <img src="../../public/ub_16pt_rgb_quer_2018.png" height="30" alt="" />
            </b-nav-item>
            <b-nav-item href="https://ern-ithaca.eu/" target="_blank" >
              <img src="https://ern-ithaca.eu/wp-content/uploads/2020/04/ITHACA-logo.jpg" height="30" alt="" />
            </b-nav-item>
          </b-navbar-nav>
        </b-collapse>
    </b-navbar>
    </footer>

  </div>
</template>

<script>
export default {
  name: 'Footer',
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
