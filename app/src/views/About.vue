<template>
  <div class="container-fluid" style="min-height:90vh">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="8">

          <div class="accordion" role="tablist">
              <b-card no-body class="mb-1">
                <b-card-header header-tag="header" class="p-1" role="tab">
                  <b-button block v-b-toggle.accordion-1 variant="info" class="text-left">About SysNDD</b-button>
                </b-card-header>
                <b-collapse id="accordion-1" visible accordion="my-accordion" role="tabpanel">
                  <b-card-body>
                    <b-card-text class="text-left">
                    The SysNDD database contains gene disease relationships manually curated from the literature based on the previous curation effort in SysID.
                    Our long-term goal is incorporation of the SysNDD/SysID data into other gene disease relationship databases like the Orphanet ontology.
                    To allow interoperability and mapping between gene-, phenotype- or disease-oriented databases we center our approach around curated gene-inheritance-disease units, so called entities, 
                    which are annotated with a predefined list of NDD associated phenotypes.
                  </b-card-text>
                  </b-card-body>
                </b-collapse>
              </b-card>

              <b-card no-body class="mb-1">
                <b-card-header header-tag="header" class="p-1" role="tab">
                  <b-button block v-b-toggle.accordion-2 variant="info" class="text-left">Citation Policy</b-button>
                </b-card-header>
                <b-collapse id="accordion-2" accordion="my-accordion" role="tabpanel">
                  <b-card-body>
                    <b-card-text class="text-left">
                      In addition to this website, the data powering SysNDD has been described in these publications:
                      <b-link href="https://pubmed.ncbi.nlm.nih.gov/26748517/" target="_blank"> 
                      1. Kochinke & Zweier et al. 2016
                      </b-link> 
                    </b-card-text>
                  </b-card-body>
                </b-collapse>
              </b-card>

              <b-card no-body class="mb-1">
                <b-card-header header-tag="header" class="p-1" role="tab">
                  <b-button block v-b-toggle.accordion-3 variant="info" class="text-left">Support and Funding</b-button>
                </b-card-header>
                <b-collapse id="accordion-3" accordion="my-accordion" role="tabpanel">
                  <b-card-body>
                    <b-card-text class="text-left">
                      The previous SysID database and data curation was supported by:
                      - The European Union’s FP7 large scale integrated network GenCoDys (HEALTH-241995) to C Webber, MA Huynen and A Schenck
                      - VIDI and TOP grants (917-96-346, 912-12-109) from The Netherlands Organisation for Scientific Research (NWO) to A Schenck
                      - the IZKF (Interdisziplinäres Zentrum für Klinische Forschung) Erlangen to C Zweier
                      - DFG (Deutsche Forschungsgemeinschaft) grant ZW184/1-1 and -2 to C Zweier
                      - ZonMw grant (NWO, 907-00-365) to T Kleefstra
                    </b-card-text>
                  </b-card-body>
                </b-collapse>
              </b-card>

              <b-card no-body class="mb-1">
                <b-card-header header-tag="header" class="p-1" role="tab">
                  <b-button block v-b-toggle.accordion-4 variant="info" class="text-left">News and Updates</b-button>
                </b-card-header>
                <b-collapse id="accordion-4" accordion="my-accordion" role="tabpanel">
                  <b-card-body>
                    <b-card-text>{{ text }}</b-card-text>
                  </b-card-body>
                </b-collapse>
              </b-card>

              <b-card no-body class="mb-1">
                <b-card-header header-tag="header" class="p-1" role="tab">
                  <b-button block v-b-toggle.accordion-5 variant="info" class="text-left">Help and FAQ</b-button>
                </b-card-header>
                <b-collapse id="accordion-5" accordion="my-accordion" role="tabpanel">
                  <b-card-body>
                    <b-card-text>{{ text }}</b-card-text>
                  </b-card-body>
                </b-collapse>
              </b-card>

              <b-card no-body class="mb-1">
                <b-card-header header-tag="header" class="p-1" role="tab">
                  <b-button block v-b-toggle.accordion-6 variant="info" class="text-left">Disclaimer</b-button>
                </b-card-header>
                <b-collapse id="accordion-6" accordion="my-accordion" role="tabpanel">
                  <b-card-body>
                    <b-card-text>{{ text }}</b-card-text>
                  </b-card-body>
                </b-collapse>
              </b-card>

              <b-card no-body class="mb-1">
                <b-card-header header-tag="header" class="p-1" role="tab">
                  <b-button block v-b-toggle.accordion-7 variant="info" class="text-left">Contact</b-button>
                </b-card-header>
                <b-collapse id="accordion-7" accordion="my-accordion" role="tabpanel">
                  <b-card-body>
                    <b-card-text>{{ text }}</b-card-text>
                  </b-card-body>
                </b-collapse>
              </b-card>
            </div>




        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
export default {
  name: 'About',
  data() {
      return {
        name: 'About',
        loading: false
      }
    }
  }
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
</style>
