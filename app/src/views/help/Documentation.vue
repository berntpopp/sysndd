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
                  v-b-toggle.accordion-6
                  block
                  variant="info"
                  class="text-start"
                >
                  Docs and FAQ
                </b-button>
              </b-card-header>
              <b-collapse
                id="accordion-6"
                visible
                accordion="my-accordion"
                role="tabpanel"
              >
                <b-card-body>
                  <b-container
                    fluid="sm"
                    class="text-start py-2"
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
          </div>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
export default {
  name: 'Documentation',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Documentation',
    // all titles will be injected into this template
    titleTemplate:
      '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en',
    },
    meta: [
      {
        vmid: 'description',
        name: 'description',
        content:
          'The Documentation view contains information about the SysNDD curation effort and website.',
      },
    ],
  },
  data() {
    return {
      name: 'Documentation',
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
