<template>
  <div class="container-fluid">
    <b-spinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <b-container
      v-else
      fluid
    >
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="8"
        >
          <div
            class="accordion"
            role="tablist"
          >
            <b-card
              no-body
              class="mb-1"
            >
              <b-card-header
                header-tag="header"
                class="p-1"
                role="tab"
              >
                <b-button
                  v-b-toggle.accordion-1
                  block
                  variant="info"
                  class="text-left"
                >
                  About SysNDD and it's creators
                </b-button>
              </b-card-header>
              <b-collapse
                id="accordion-1"
                visible
                accordion="my-accordion"
                role="tabpanel"
              >
                <b-card-body>
                  <b-container
                    fluid="sm"
                    class="text-left py-2"
                  >
                    The SysNDD database is based on its predecessor database,
                    SysID (https://www.sysid.dbmr.unibe.ch/). It contains a
                    manually curated catalogue of published genes implicated in
                    neurodevelopmental disorders (NDDs) and classified into
                    primary and candidate genes according to the degree of
                    underlying evidence. Furthermore, manually curated
                    information on associated diseases and phenotypes is
                    provided. To allow interoperability and mapping between
                    gene-, phenotype- or disease-oriented databases, we center
                    our approach around curated gene-inheritance-disease units,
                    so called entities. SysNDD is updated every 3-4 months and
                    can be utilized for a broad spectrum of tasks from both
                    research and diagnostics. One of our long-term goals is to
                    incorporate the SysID/SysNDD data into other
                    gene/disease-relationship databases like the Orphanet
                    ontology.
                  </b-container>
                  <b-container
                    fluid="sm"
                    class="text-left py-2"
                  >
                    SysNDD has been built and is maintained by Christiane Zweier
                    (Head of the Department of Human Genetics at the University/
                    University Hospital Bern, Switzerland) and Bernt Popp
                    (senior physician at the Institute for Clinical Genetics,
                    University Hospital TU Dresden, Germany and scientist at the
                    Institute of Human Genetics at the University Hospital
                    Leipzig, Germany). CZ has been involved in establishing and
                    updating SysID from its start in 2009. She is performing and
                    coordinating curation and updates. BP developed and
                    programmed the new SysNDD database and will be integrating
                    further functionality including associated variants and
                    network analyses in future updates.
                  </b-container>
                </b-card-body>
              </b-collapse>
            </b-card>

            <b-card
              no-body
              class="mb-1"
            >
              <b-card-header
                header-tag="header"
                class="p-1"
                role="tab"
              >
                <b-button
                  v-b-toggle.accordion-2
                  block
                  variant="info"
                  class="text-left"
                >
                  Citation Policy
                </b-button>
              </b-card-header>
              <b-collapse
                id="accordion-2"
                accordion="my-accordion"
                role="tabpanel"
              >
                <b-card-body>
                  <b-container
                    fluid="sm"
                    class="text-left py-2"
                  >
                    <b-row>
                      <b-col md="12">
                        We are currently working on manuscripts describing (1)
                        the development of SysID through the last years and (2)
                        the new SysNDD database. Until then please cite the
                        publication below if you use SysID or data from SysID in
                        your work.
                      </b-col>
                    </b-row>
                    <b-row>
                      <b-col md="12">
                        <span class="font-weight-bold">1.</span>
                        <b-link
                          href="https://pubmed.ncbi.nlm.nih.gov/26748517/"
                          target="_blank"
                        >
                          Kochinke K, Zweier C, Nijhof B, Fenckova M, Cizek P,
                          Honti F, Keerthikumar S, Oortveld MA, Kleefstra T,
                          Kramer JM, Webber C, Huynen MA, Schenck A. Systematic
                          Phenomics Analysis Deconvolutes Genes Mutated in
                          Intellectual Disability into Biologically Coherent
                          Modules. Am J Hum Genet. 2016 Jan 7;98(1):149-64. doi:
                          10.1016/j.ajhg.2015.11.024. PMID: 26748517; PMCID:
                          PMC4716705.
                        </b-link>
                      </b-col>
                    </b-row>
                  </b-container>
                </b-card-body>
              </b-collapse>
            </b-card>

            <b-card
              no-body
              class="mb-1"
            >
              <b-card-header
                header-tag="header"
                class="p-1"
                role="tab"
              >
                <b-button
                  v-b-toggle.accordion-3
                  block
                  variant="info"
                  class="text-left"
                >
                  Support and Funding
                </b-button>
              </b-card-header>
              <b-collapse
                id="accordion-3"
                accordion="my-accordion"
                role="tabpanel"
              >
                <b-container
                  fluid="sm"
                  class="text-left py-2"
                >
                  <b-row>
                    <b-col md="12">
                      The current SysNDD database development is supported by:
                    </b-col>
                  </b-row>
                  <b-row>
                    <b-col md="12">
                      - DFG (Deutsche Forschungsgemeinschaft) grant PO2366/2-1
                      to
                      <b-link
                        href="https://orcid.org/0000-0002-3679-1081"
                        target="_blank"
                      >
                        Bernt Popp
                      </b-link>.
                    </b-col>
                  </b-row>
                  <b-row>
                    <b-col md="12">
                      - DFG (Deutsche Forschungsgemeinschaft) grant ZW184/6-1 to
                      <b-link
                        href="https://orcid.org/0000-0001-8002-2020"
                        target="_blank"
                      >
                        Christiane Zweier
                      </b-link>.
                    </b-col>
                  </b-row>
                  <b-row>
                    <b-col md="12">
                      - ITHACA ERN through
                      <b-link
                        href="https://orcid.org/0000-0003-4819-0264"
                        target="_blank"
                      >
                        Alain Verloes
                      </b-link>.
                    </b-col>
                  </b-row>
                </b-container>

                <b-container
                  fluid="sm"
                  class="text-left py-2"
                >
                  <b-row>
                    <b-col md="12">
                      The previous SysID database and data curation was
                      supported by:
                    </b-col>
                  </b-row>
                  <b-row>
                    <b-col md="12">
                      - The European Union’s FP7 large scale integrated network
                      GenCoDys (HEALTH-241995) to MA Huynen and
                      <b-link
                        href="https://orcid.org/0000-0002-6918-3314"
                        target="_blank"
                      >
                        Annette Schenck
                      </b-link>.
                    </b-col>
                  </b-row>
                  <b-row>
                    <b-col md="12">
                      - VIDI and TOP grants (917-96-346, 912-12-109) from The
                      Netherlands Organisation for Scientific Research (NWO) to
                      <b-link
                        href="https://orcid.org/0000-0002-6918-3314"
                        target="_blank"
                      >
                        Annette Schenck
                      </b-link>.
                    </b-col>
                  </b-row>
                  <b-row>
                    <b-col md="12">
                      - DFG (Deutsche Forschungsgemeinschaft) grants ZW184/1-1
                      and -2 to
                      <b-link
                        href="https://orcid.org/0000-0001-8002-2020"
                        target="_blank"
                      >
                        Christiane Zweier
                      </b-link>.
                    </b-col>
                  </b-row>
                  <b-row>
                    <b-col md="12">
                      - the IZKF (Interdisziplinäres Zentrum für Klinische
                      Forschung) Erlangen to
                      <b-link
                        href="https://orcid.org/0000-0001-8002-2020"
                        target="_blank"
                      >
                        Christiane Zweier
                      </b-link>.
                    </b-col>
                  </b-row>
                  <b-row>
                    <b-col md="12">
                      - ZonMw grant (NWO, 907-00-365) to
                      <b-link
                        href="https://orcid.org/0000-0002-0956-0237"
                        target="_blank"
                      >
                        Tjitske Kleefstra
                      </b-link>.
                    </b-col>
                  </b-row>
                </b-container>
              </b-collapse>
            </b-card>

            <b-card
              no-body
              class="mb-1"
            >
              <b-card-header
                header-tag="header"
                class="p-1"
                role="tab"
              >
                <b-button
                  v-b-toggle.accordion-4
                  block
                  variant="info"
                  class="text-left"
                >
                  News and Updates
                </b-button>
              </b-card-header>
              <b-collapse
                id="accordion-4"
                accordion="my-accordion"
                role="tabpanel"
              >
                <b-card-body>
                  <b-container
                    fluid="sm"
                    class="text-left py-2"
                  >
                    <b-card-text class="text-left">
                      <span class="font-weight-bold">2022-05-07:</span> First
                      SysNDD native data update. depricating SysID. SysNDD now
                      in usable beta mode.
                    </b-card-text>
                    <b-card-text class="text-left">
                      <span class="font-weight-bold">2021-11-09:</span> Several
                      updates to the APP, API and DB preparing it for re-review
                      mode.
                    </b-card-text>
                    <b-card-text class="text-left">
                      <span class="font-weight-bold">2021-08-16:</span> SysNDD
                      is currently in alpha development status and changes. We
                      currently recommend using the stable
                      <b-link
                        href="https://www.sysid.dbmr.unibe.ch/"
                        target="_blank"
                      >
                        SysID database
                      </b-link>
                      for your work until a more stable beta status is reached.
                    </b-card-text>
                  </b-container>
                </b-card-body>
              </b-collapse>
            </b-card>

            <b-card
              no-body
              class="mb-1"
            >
              <b-card-header
                header-tag="header"
                class="p-1"
                role="tab"
              >
                <b-button
                  v-b-toggle.accordion-5
                  block
                  variant="info"
                  class="text-left"
                >
                  Credits
                </b-button>
              </b-card-header>
              <b-collapse
                id="accordion-5"
                accordion="my-accordion"
                role="tabpanel"
              >
                <b-card-body>
                  <b-container
                    fluid="sm"
                    class="text-left py-2"
                  >
                    We would like to acknowledge Annette Schenck and Martijn
                    Huynen and their groups from Radboud University Medical
                    Center Nijmegen, The Netherlands, who initially brought
                    SysID into life and maintained and supported it for many
                    years. We would also like to thank all users for using SysID
                    and for positive feedbacks, thus making the sometimes
                    tedious updates and the re-organization into the new SysNDD
                    database worth it. Since recently, Alain Verloes and ERN
                    ITHACA provide valuable encouragement and support by
                    initiating and supporting the data integration with Orphanet
                    and helping with the recruitment of expert curators.
                  </b-container>
                </b-card-body>
              </b-collapse>
            </b-card>

            <b-card
              no-body
              class="mb-1"
            >
              <b-card-header
                header-tag="header"
                class="p-1"
                role="tab"
              >
                <b-button
                  v-b-toggle.accordion-6
                  block
                  variant="info"
                  class="text-left"
                >
                  Help and FAQ
                </b-button>
              </b-card-header>
              <b-collapse
                id="accordion-6"
                accordion="my-accordion"
                role="tabpanel"
              >
                <b-card-body>
                  <b-container
                    fluid="sm"
                    class="text-left py-2"
                  >
                    <b-row>
                      <b-col md="12">
                        <span class="font-weight-bold">
                          1. What can I use SysNDD for?
                        </span>
                      </b-col>
                    </b-row>
                    <b-row>
                      <b-col md="12">
                        SysNDD can be used for various purposes and questions.
                        A) Gene lists can be downloaded, either all genes
                        implicated with NDDs or lists distinguished by their
                        level of evidence. Furthermore, gene lists can be
                        filtered based on associated phenotypes. B) Single
                        entries can be searched and looked up either starting
                        from a gene or from a disease. Also lists and summaries
                        on genes associated with a disease or diseases
                        associated with a particular gene can be retrieved.<br><br>
                      </b-col>
                    </b-row>

                    <b-row>
                      <b-col md="12">
                        <span class="font-weight-bold">
                          2. What are the criteria for inclusion and curation of
                          genes and diseases in SysNDD?
                        </span>
                      </b-col>
                    </b-row>
                    <b-row>
                      <b-col md="12">
                        We only use information that is published and no
                        un-published data from meetings/conferences, personal
                        communication or in-house databases. This means that for
                        all information contained in SysNDD the primary source
                        can be retrieved.<br><br>
                      </b-col>
                    </b-row>

                    <b-row>
                      <b-col md="12">
                        <span class="font-weight-bold">
                          3. What is the concept of the SysNDD-entities?
                        </span>
                      </b-col>
                    </b-row>
                    <b-row>
                      <b-col md="12">
                        The core principle of SysNDD are immutable
                        “gene-inheritance-disease” units, so called “entities”.
                        <br>
                        <h2>
                          <b-badge variant="primary">
                            Entity:
                            <b-badge
                              pill
                              variant="success"
                            >
                              Gene
                            </b-badge>
                            <b-badge
                              pill
                              variant="info"
                            >
                              Inheritance
                            </b-badge>
                            <b-badge
                              pill
                              variant="secondary"
                            >
                              Disease
                            </b-badge>
                          </b-badge>
                        </h2>
                        To allow interoperability and linking to other data
                        sources, these entities are defined through ontology
                        terms (HGNC identifier for genes, OMIM or MONDO for
                        disease and inheritance from HPO). The mutational
                        consequence is currently not active but will be
                        implemented with the next updates.<br><br>
                      </b-col>
                    </b-row>

                    <b-row>
                      <b-col md="12">
                        <span class="font-weight-bold">
                          4. Who is updating and curating the data?
                        </span>
                      </b-col>
                    </b-row>
                    <b-row>
                      <b-col md="12">
                        Genes and phenotypes contained in SysID/SysNDD have been
                        updated and curated by CZ since 2009. In future, experts
                        from ERN ITHACA will be involved the curation and
                        updating process.<br><br>
                      </b-col>
                    </b-row>

                    <b-row>
                      <b-col md="12">
                        <span class="font-weight-bold">
                          5. Can I see if a variant in a particular gene might
                          be pathogenic?
                        </span>
                      </b-col>
                    </b-row>
                    <b-row>
                      <b-col md="12">
                        No, this information is not (yet) provided in SysNDD.<br><br>
                      </b-col>
                    </b-row>

                    <b-row>
                      <b-col md="12">
                        <span class="font-weight-bold">
                          6. What makes SysNDD different from other NDD
                          databases?
                        </span>
                      </b-col>
                    </b-row>
                    <b-row>
                      <b-col md="12">
                        SysNDD is one of the few NDD-related databases that
                        contains not only information on genes but also on
                        associated diseases, inheritance patterns and
                        phenotypes, all organized in entities. It is manually
                        curated by a single or a limited number of experts thus
                        ensuring high confidence of the data.<br><br>
                      </b-col>
                    </b-row>

                    <b-row>
                      <b-col md="12">
                        <span class="font-weight-bold">
                          7. Where can I find information on how to use SysNDD
                          and its concepts?
                        </span>
                      </b-col>
                    </b-row>
                    <b-row>
                      <b-col md="12">
                        The SysNDD documentation is generated usign bookdown and
                        hosted on our GitHub docs page at
                        <b-link
                          href="https://berntpopp.github.io/sysndd/"
                          target="_blank"
                        >
                          https://berntpopp.github.io/sysndd/
                        </b-link>. You can browse the webpage, download the content in
                        different formats (PDF, DOCS, EPUB) and even help
                        improve the documentation by editing it on GitHub.<br><br>
                      </b-col>
                    </b-row>

                    <b-row>
                      <b-col md="12">
                        <span class="font-weight-bold">
                          8. You found a bug, have a problem with the site or
                          data or want to help improve the service?
                        </span>
                      </b-col>
                    </b-row>
                    <b-row>
                      <b-col md="12">
                        Ask questions, report bugs and chat about SysNDD in
                        general using our
                        <b-link
                          href="https://github.com/berntpopp/sysndd/discussions"
                          target="_blank"
                        >
                          Github discussions page
                        </b-link>.<br><br>
                      </b-col>
                    </b-row>
                  </b-container>
                </b-card-body>
              </b-collapse>
            </b-card>

            <b-card
              no-body
              class="mb-1"
            >
              <b-card-header
                header-tag="header"
                class="p-1"
                role="tab"
              >
                <b-button
                  v-b-toggle.accordion-7
                  block
                  variant="info"
                  class="text-left"
                >
                  Disclaimer
                </b-button>
              </b-card-header>
              <b-collapse
                id="accordion-7"
                accordion="my-accordion"
                role="tabpanel"
              >
                <b-card-body>
                  <b-container
                    fluid="sm"
                    class="text-left py-2"
                  >
                    The Department of Human Genetics (University Hospital,
                    University Bern, Bern, Switzerland) makes no representation
                    about the suitability or accuracy of this software or data
                    for any purpose, and makes no warranties, including fitness
                    for a particular purpose or that the use of this software
                    will not infringe any third party patents, copyrights,
                    trademarks or other rights.
                  </b-container>
                  <b-container
                    fluid="sm"
                    class="text-left py-2"
                  >
                    <span
                      class="font-weight-bold"
                    >Responsible for this website:</span>
                    Bernt Popp (admin [at] sysndd.org)
                  </b-container>
                  <b-container
                    fluid="sm"
                    class="text-left py-2"
                  >
                    <span
                      class="font-weight-bold"
                    >Responsible for this project:</span>
                    Christiane Zweier (curator [at] sysndd.org)
                  </b-container>
                  <b-container
                    fluid="sm"
                    class="text-left py-2"
                  >
                    <span class="font-weight-bold">Address:</span>
                    Universitätsklinik für Humangenetik, Inselspital,
                    Universitätsspital Bern, Freiburgstrasse 15, 3010 Bern,
                    Switzerland
                  </b-container>
                </b-card-body>
              </b-collapse>
            </b-card>

            <b-card
              no-body
              class="mb-1"
            >
              <b-card-header
                header-tag="header"
                class="p-1"
                role="tab"
              >
                <b-button
                  v-b-toggle.accordion-8
                  block
                  variant="info"
                  class="text-left"
                >
                  Contact
                </b-button>
              </b-card-header>
              <b-collapse
                id="accordion-8"
                accordion="my-accordion"
                role="tabpanel"
              >
                <b-card-body>
                  <b-container
                    fluid="sm"
                    class="text-left py-2"
                  >
                    If you have technical problems using SysNDD or requests
                    regarding the data or functionality, please contact us at
                    support [at] sysndd.org.
                  </b-container>
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
  name: "About",
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: "About",
    // all titles will be injected into this template
    titleTemplate:
      "%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders",
    htmlAttrs: {
      lang: "en",
    },
    meta: [
      {
        vmid: "description",
        name: "description",
        content:
          "The About view contains information abouit the SysNDD curation effort and website.",
      },
    ],
  },
  data() {
    return {
      name: "About",
      loading: false,
    };
  },
};
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}
</style>
