<template>
  <div class="container-fluid bg-light">
    <BSpinner v-if="loading" label="Loading..." class="d-block mx-auto my-5" />
    <BContainer v-else fluid>
      <BRow class="justify-content-md-center py-4">
        <BCol col md="10" lg="8">
          <!-- Page Header -->
          <div class="text-center mb-4">
            <h2 class="fw-bold text-primary">
              <i class="bi bi-book me-2" />
              Documentation & FAQ
            </h2>
            <p class="text-muted">
              Learn how to use SysNDD and get answers to frequently asked questions
            </p>
          </div>

          <!-- Quick Links Card -->
          <BCard class="mb-4 border-0 shadow-sm" body-class="py-3">
            <BRow class="text-center">
              <BCol sm="4" class="mb-2 mb-sm-0">
                <BLink :href="DOCS_URLS.HOME" target="_blank" class="text-decoration-none">
                  <i class="bi bi-file-earmark-text fs-2 d-block mb-2 text-primary" />
                  <span class="fw-semibold">Full Documentation</span>
                </BLink>
              </BCol>
              <BCol sm="4" class="mb-2 mb-sm-0">
                <BLink :href="DOCS_URLS.GITHUB_DISCUSSIONS" target="_blank" class="text-decoration-none">
                  <i class="bi bi-chat-dots fs-2 d-block mb-2 text-success" />
                  <span class="fw-semibold">Discussions</span>
                </BLink>
              </BCol>
              <BCol sm="4">
                <BLink :href="DOCS_URLS.GITHUB_ISSUES" target="_blank" class="text-decoration-none">
                  <i class="bi bi-bug fs-2 d-block mb-2 text-danger" />
                  <span class="fw-semibold">Report Issues</span>
                </BLink>
              </BCol>
            </BRow>
          </BCard>

          <!-- FAQ Accordion -->
          <BAccordion id="faq-accordion">
            <BAccordionItem title="What can I use SysNDD for?" visible>
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-1-circle me-2 text-primary" />
                  What can I use SysNDD for?
                </span>
              </template>
              <div class="py-2">
                <p>SysNDD can be used for various purposes and questions:</p>
                <BListGroup flush>
                  <BListGroupItem class="bg-transparent d-flex">
                    <BBadge variant="primary" class="me-3 align-self-start"> A </BBadge>
                    <div>
                      Gene lists can be downloaded, either all genes implicated with NDDs or lists
                      distinguished by their level of evidence. Furthermore, gene lists can be
                      filtered based on associated phenotypes.
                    </div>
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent d-flex">
                    <BBadge variant="primary" class="me-3 align-self-start"> B </BBadge>
                    <div>
                      Single entries can be searched and looked up either starting from a gene or
                      from a disease. Also lists and summaries on genes associated with a disease or
                      diseases associated with a particular gene can be retrieved.
                    </div>
                  </BListGroupItem>
                </BListGroup>
              </div>
            </BAccordionItem>

            <BAccordionItem title="What are the criteria for inclusion?">
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-2-circle me-2 text-primary" />
                  What are the criteria for inclusion and curation of genes and diseases?
                </span>
              </template>
              <div class="py-2">
                <BAlert variant="info" show>
                  <i class="bi bi-info-circle me-2" />
                  We only use information that is <strong>published</strong> and no unpublished data
                  from meetings/conferences, personal communication or in-house databases.
                </BAlert>
                <p>
                  This means that for all information contained in SysNDD the primary source can be
                  retrieved.
                </p>
              </div>
            </BAccordionItem>

            <BAccordionItem title="What is the concept of entities?">
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-3-circle me-2 text-primary" />
                  What is the concept of the SysNDD-entities?
                </span>
              </template>
              <div class="py-2">
                <p>
                  The core principle of SysNDD are immutable "gene-inheritance-disease" units, so
                  called "entities".
                </p>

                <BCard class="text-center mb-4 border-0 bg-primary bg-opacity-10" body-class="py-4">
                  <h4 class="mb-0">
                    <BBadge variant="primary" class="px-4 py-3">
                      Entity:
                      <BBadge pill variant="success" class="mx-1"> Gene </BBadge>
                      <BBadge pill variant="info" class="mx-1"> Inheritance </BBadge>
                      <BBadge pill variant="secondary" class="mx-1"> Disease </BBadge>
                    </BBadge>
                  </h4>
                </BCard>

                <p>
                  To allow interoperability and linking to other data sources, these entities are
                  defined through ontology terms:
                </p>
                <BListGroup flush>
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-check-lg text-success me-2" />
                    <strong>HGNC identifier</strong> for genes
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-check-lg text-success me-2" />
                    <strong>OMIM or MONDO</strong> for disease
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-check-lg text-success me-2" />
                    <strong>HPO</strong> for inheritance
                  </BListGroupItem>
                </BListGroup>
                <p class="mt-3 text-muted">
                  <i class="bi bi-info-circle me-1" />
                  The mutational consequence is currently not active but will be implemented with
                  the next updates.
                </p>
              </div>
            </BAccordionItem>

            <BAccordionItem title="Who is updating the data?">
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-4-circle me-2 text-primary" />
                  Who is updating and curating the data?
                </span>
              </template>
              <div class="py-2">
                <p>
                  Genes and phenotypes contained in SysID/SysNDD have been updated and curated by
                  <strong>Christiane Zweier (CZ)</strong> since 2009.
                </p>
                <p>
                  In future, experts from <strong>ERN ITHACA</strong> will be involved in the
                  curation and updating process.
                </p>
              </div>
            </BAccordionItem>

            <BAccordionItem title="Can I check variant pathogenicity?">
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-5-circle me-2 text-primary" />
                  Can I see if a variant in a particular gene might be pathogenic?
                </span>
              </template>
              <div class="py-2">
                <BAlert variant="warning" show>
                  <i class="bi bi-exclamation-triangle me-2" />
                  <strong>No</strong>, this information is not (yet) provided in SysNDD.
                </BAlert>
              </div>
            </BAccordionItem>

            <BAccordionItem title="What makes SysNDD different?">
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-6-circle me-2 text-primary" />
                  What makes SysNDD different from other NDD databases?
                </span>
              </template>
              <div class="py-2">
                <p>
                  SysNDD is one of the few NDD-related databases that contains not only information
                  on genes but also on:
                </p>
                <BRow class="text-center my-4">
                  <BCol sm="3">
                    <BCard class="border-0 bg-success bg-opacity-10 h-100" body-class="py-3">
                      <i class="bi bi-dna fs-2 text-success" />
                      <div class="fw-semibold mt-2">Genes</div>
                    </BCard>
                  </BCol>
                  <BCol sm="3">
                    <BCard class="border-0 bg-info bg-opacity-10 h-100" body-class="py-3">
                      <i class="bi bi-virus fs-2 text-info" />
                      <div class="fw-semibold mt-2">Diseases</div>
                    </BCard>
                  </BCol>
                  <BCol sm="3">
                    <BCard class="border-0 bg-warning bg-opacity-10 h-100" body-class="py-3">
                      <i class="bi bi-diagram-3 fs-2 text-warning" />
                      <div class="fw-semibold mt-2">Inheritance</div>
                    </BCard>
                  </BCol>
                  <BCol sm="3">
                    <BCard class="border-0 bg-danger bg-opacity-10 h-100" body-class="py-3">
                      <i class="bi bi-clipboard2-pulse fs-2 text-danger" />
                      <div class="fw-semibold mt-2">Phenotypes</div>
                    </BCard>
                  </BCol>
                </BRow>
                <p>
                  All organized in <strong>entities</strong>. It is manually curated by a single or
                  a limited number of experts thus ensuring <strong>high confidence</strong> of the
                  data.
                </p>
              </div>
            </BAccordionItem>

            <BAccordionItem title="Where can I find more documentation?">
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-7-circle me-2 text-primary" />
                  Where can I find information on how to use SysNDD and its concepts?
                </span>
              </template>
              <div class="py-2">
                <p>
                  The SysNDD documentation is generated using bookdown and hosted on our GitHub docs
                  page at:
                </p>
                <BCard class="text-center border-0 bg-primary bg-opacity-10" body-class="py-4">
                  <BLink :href="DOCS_URLS.HOME" target="_blank" class="fs-5 fw-bold">
                    <i class="bi bi-box-arrow-up-right me-2" />
                    {{ DOCS_URLS.HOME }}
                  </BLink>
                </BCard>
                <p class="mt-3">You can:</p>
                <BListGroup flush>
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-globe text-primary me-2" />
                    Browse the webpage
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-download text-primary me-2" />
                    Download the content in different formats (PDF, DOCS, EPUB)
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-pencil text-primary me-2" />
                    Help improve the documentation by editing it on GitHub
                  </BListGroupItem>
                </BListGroup>
              </div>
            </BAccordionItem>

            <BAccordionItem title="Found a bug or want to help?">
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-8-circle me-2 text-primary" />
                  You found a bug, have a problem, or want to help improve the service?
                </span>
              </template>
              <div class="py-2">
                <p>Ask questions, report bugs and chat about SysNDD in general using our:</p>
                <BCard class="text-center border-0 bg-success bg-opacity-10" body-class="py-4">
                  <BLink :href="DOCS_URLS.GITHUB_DISCUSSIONS" target="_blank" class="fs-5 fw-bold text-success">
                    <i class="bi bi-github me-2" />
                    GitHub Discussions Page
                  </BLink>
                </BCard>
              </div>
            </BAccordionItem>
          </BAccordion>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import { DOCS_URLS } from '@/constants/docs';

export default {
  name: 'DocumentationView',
  setup() {
    useHead({
      title: 'Documentation',
      meta: [
        {
          name: 'description',
          content:
            'The Documentation view contains information about the SysNDD curation effort and website.',
        },
      ],
    });

    return {
      DOCS_URLS,
    };
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
.bg-light {
  background-color: #f8f9fa !important;
}

.bg-opacity-10 {
  --bs-bg-opacity: 0.1;
}
</style>
