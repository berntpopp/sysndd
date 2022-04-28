<template>
  <div class="footer">

    <b-navbar toggleable="sm" type="light" variant="light" class="py-0 bg-footer">
      <b-navbar-toggle target="footer-collapse"></b-navbar-toggle>
        <b-collapse id="footer-collapse" is-nav>
          <b-navbar-nav justified class="flex-grow-1">
            <b-nav-item :link-attrs="link['license']" href="http://creativecommons.org/licenses/by/4.0/" target="_blank">
              <img src="../../public/licensebuttons.netlby4.0_88x31.png" height="34" width="96.52" alt="Creative Commons License" />
            </b-nav-item>
            <b-nav-item :link-attrs="link['github']" href="https://github.com/berntpopp/sysndd" target="_blank">
              <img src="../../public/GitHub-Mark-64px_white.png" height="34" width="34" alt="GitHub Logo" />
            </b-nav-item>
            <b-nav-item :link-attrs="link['api']" href="/API">
              <img src="../../public/swagger.png" height="34" width="34" alt="Swagger OpenAPI Logo" />
            </b-nav-item>
            <b-nav-item :link-attrs="link['dfg']" href="https://www.dfg.de/" target="_blank">
              <img src="../../public/dfg_logo_foerderung/dfg_logo_schriftzug_blau_foerderung_4c.png" height="34" width="120" alt="DFG gefördert Logo" />
            </b-nav-item>
            <b-nav-item :link-attrs="link['unibe']" href="https://www.unibe.ch/" target="_blank">
              <img src="../../public/ub_16pt_rgb_quer_2018_68px.png" height="34" width="107" alt="Universität Bern Logo" />
            </b-nav-item>
            <b-nav-item :link-attrs="link['ern-ithaca']" href="https://ern-ithaca.eu/" target="_blank" >
              <img src="../../public/logo_blue_tiny.png" height="34" width="159" alt="ERN ITHACA Logo" />
            </b-nav-item>
          </b-navbar-nav>
        </b-collapse>
    </b-navbar>

  </div>
</template>

<script>
export default {
  name: 'Footer',
  data() {
        return {
          link: {'license': {"aria-label": "license-link"}, 'github': {"aria-label": "github-link"}, 'api': {"aria-label": "api-link"}, 'dfg': {"aria-label": "dfg-link"}, 'unibe': {"aria-label": "unibe-link"}, 'ern-ithaca': {"aria-label": "ern-ithaca-link"}}
        }
  }
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
.bg-footer {
  background-image: linear-gradient(to top, #d5d4d0 0%, #d5d4d0 1%, #eeeeec 31%, #efeeec 75%, #e9e9e7 100%);
}
</style>
