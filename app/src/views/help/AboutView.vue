<template>
  <div class="container-fluid bg-light">
    <BSpinner
      v-if="loading"
      label="Loading..."
      class="d-block mx-auto my-5"
    />
    <BContainer
      v-else
      fluid
    >
      <BRow class="justify-content-md-center py-4">
        <BCol
          col
          md="10"
          lg="8"
        >
          <!-- Page Header -->
          <div class="text-center mb-4">
            <h2 class="fw-bold text-primary">
              <i class="bi bi-info-circle me-2" />
              About SysNDD
            </h2>
            <p class="text-muted">
              Learn about the SysNDD database, its creators, and how to cite our work
            </p>
          </div>

          <!-- Dynamic Accordion from CMS (if available) -->
          <BAccordion v-if="useCmsContent && cmsContent.length > 0" id="about-accordion">
            <BAccordionItem
              v-for="(section, index) in cmsContent"
              :key="section.section_id"
              :visible="index === 0"
            >
              <template #title>
                <span class="fw-semibold">
                  <i :class="section.icon + ' me-2'" />
                  {{ section.title }}
                </span>
              </template>
              <div v-dompurify-html="renderMarkdown(section.content)" class="py-2 about-content" />
            </BAccordionItem>
          </BAccordion>

          <!-- Default Hardcoded Accordion (fallback) -->
          <BAccordion v-else id="about-accordion">
            <BAccordionItem
              title="About SysNDD and its creators"
              visible
            >
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-people me-2" />
                  About SysNDD and its creators
                </span>
              </template>
              <div class="py-2">
                <p>
                  The SysNDD database is based on some content of its predecessor database, SysID
                  (<BLink href="http://sysid.cmbi.umcn.nl/" target="_blank">http://sysid.cmbi.umcn.nl/</BLink>,
                  more recently <BLink href="https://www.sysid.dbmr.unibe.ch/" target="_blank">https://www.sysid.dbmr.unibe.ch/</BLink>).
                  The concept for a curated gene collection and database with the goal to facilitate research and
                  diagnostics into NDDs has been conceived by Annette Schenck and Christiane Zweier.
                </p>
                <p>
                  In 2009, they established SysID with a manually curated catalog of published genes implicated in
                  neurodevelopmental disorders (NDDs), classified into primary and candidate genes according to the
                  degree of underlying evidence. Furthermore, expert curated information on associated diseases and
                  phenotypes was provided.
                </p>
                <p>
                  Christiane Zweier has been updating SysID from its start in 2009. Together with her, Bernt Popp
                  has now developed and programmed the new SysNDD database.
                </p>
                <p>
                  To allow interoperability and mapping between gene-, phenotype- or disease-oriented databases,
                  SysNDD is centered around curated gene-inheritance-disease units, so called entities, which are
                  classified based on three evidence categories. This can account for the increased complexity of
                  NDDs and allows to address a broader spectrum of diagnostic and research questions.
                </p>
                <p>
                  Future functionality will be expanded to annotation of variant and network analyses. Another goal
                  is to incorporate the SysID/SysNDD data into other gene/disease-relationship databases like the
                  Orphanet Rare Disease ontology database.
                </p>

                <h6 class="fw-bold mt-4 mb-3">
                  <i class="bi bi-building me-2" />
                  Affiliations
                </h6>
                <BListGroup flush>
                  <BListGroupItem class="bg-transparent">
                    <strong>Christiane Zweier:</strong> previously: Institute of Human Genetics, University Hospital,
                    FAU Erlangen, Germany; now: Human Genetics at the University/University Hospital Bern, Switzerland
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <strong>Bernt Popp:</strong> senior physician at the Berlin Institute of Health (BIH) at
                    Charite Berlin, Germany and scientist at the Institute of Human Genetics at the University
                    Hospital Leipzig, Germany
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <strong>Annette Schenck:</strong> Radboud university medical center, Nijmegen, the Netherlands
                  </BListGroupItem>
                </BListGroup>
              </div>
            </BAccordionItem>

            <BAccordionItem title="Citation Policy">
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-journal-text me-2" />
                  Citation Policy
                </span>
              </template>
              <div class="py-2">
                <BCard
                  class="mb-3 border-start border-primary border-4"
                  body-class="py-3"
                >
                  <p class="mb-2">
                    <strong>1.</strong>
                    <BLink href="https://pubmed.ncbi.nlm.nih.gov/26748517/" target="_blank">
                      Kochinke K, Zweier C, Nijhof B, Fenckova M, Cizek P, Honti F, Keerthikumar S, Oortveld MA,
                      Kleefstra T, Kramer JM, Webber C, Huynen MA, Schenck A. Systematic Phenomics Analysis
                      Deconvolutes Genes Mutated in Intellectual Disability into Biologically Coherent Modules.
                      Am J Hum Genet. 2016 Jan 7;98(1):149-64. doi: 10.1016/j.ajhg.2015.11.024. PMID: 26748517;
                      PMCID: PMC4716705.
                    </BLink>
                  </p>
                </BCard>
                <p class="text-muted">
                  Please cite above publication. We are currently working on a new manuscript reporting SysNDD
                  and the development of the NDD landscape over the past years. A link will be provided here
                  upon publication.
                </p>
              </div>
            </BAccordionItem>

            <BAccordionItem title="Support and Funding">
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-cash-stack me-2" />
                  Support and Funding
                </span>
              </template>
              <div class="py-2">
                <h6 class="fw-bold mb-3">Current SysNDD database development is supported by:</h6>
                <BListGroup flush class="mb-4">
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-check-circle-fill text-success me-2" />
                    DFG (Deutsche Forschungsgemeinschaft) grant PO2366/2-1 to
                    <BLink href="https://orcid.org/0000-0002-3679-1081" target="_blank">Bernt Popp</BLink>
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-check-circle-fill text-success me-2" />
                    DFG (Deutsche Forschungsgemeinschaft) grant ZW184/6-1 to
                    <BLink href="https://orcid.org/0000-0001-8002-2020" target="_blank">Christiane Zweier</BLink>
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-check-circle-fill text-success me-2" />
                    ITHACA ERN through
                    <BLink href="https://orcid.org/0000-0003-4819-0264" target="_blank">Alain Verloes</BLink>
                  </BListGroupItem>
                </BListGroup>

                <h6 class="fw-bold mb-3">Previous SysID database and data curation was supported by:</h6>
                <BListGroup flush>
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-check-circle text-secondary me-2" />
                    The European Union's FP7 large scale integrated network GenCoDys (HEALTH-241995)
                    <BLink href="https://orcid.org/0000-0001-6189-5491" target="_blank">Martijn A Huynen</BLink> and
                    <BLink href="https://orcid.org/0000-0002-6918-3314" target="_blank">Annette Schenck</BLink>
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-check-circle text-secondary me-2" />
                    VIDI and TOP grants (917-96-346, 912-12-109) from The Netherlands Organisation for Scientific Research (NWO) to
                    <BLink href="https://orcid.org/0000-0002-6918-3314" target="_blank">Annette Schenck</BLink>
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-check-circle text-secondary me-2" />
                    DFG (Deutsche Forschungsgemeinschaft) grants ZW184/1-1 and -2 to
                    <BLink href="https://orcid.org/0000-0001-8002-2020" target="_blank">Christiane Zweier</BLink>
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-check-circle text-secondary me-2" />
                    the IZKF (Interdisziplinares Zentrum fur Klinische Forschung) Erlangen to
                    <BLink href="https://orcid.org/0000-0001-8002-2020" target="_blank">Christiane Zweier</BLink>
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <i class="bi bi-check-circle text-secondary me-2" />
                    ZonMw grant (NWO, 907-00-365) to
                    <BLink href="https://orcid.org/0000-0002-0956-0237" target="_blank">Tjitske Kleefstra</BLink>
                  </BListGroupItem>
                </BListGroup>
              </div>
            </BAccordionItem>

            <BAccordionItem title="News and Updates">
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-megaphone me-2" />
                  News and Updates
                </span>
              </template>
              <div class="py-2">
                <div class="timeline">
                  <div class="d-flex mb-3">
                    <BBadge
                      variant="primary"
                      class="me-3 align-self-start"
                    >
                      2022-05-07
                    </BBadge>
                    <p class="mb-0">
                      First SysNDD native data update. Deprecating SysID. SysNDD now in usable beta mode.
                    </p>
                  </div>
                  <div class="d-flex mb-3">
                    <BBadge
                      variant="secondary"
                      class="me-3 align-self-start"
                    >
                      2021-11-09
                    </BBadge>
                    <p class="mb-0">
                      Several updates to the APP, API and DB preparing it for re-review mode.
                    </p>
                  </div>
                  <div class="d-flex mb-3">
                    <BBadge
                      variant="secondary"
                      class="me-3 align-self-start"
                    >
                      2021-08-16
                    </BBadge>
                    <p class="mb-0">
                      SysNDD is currently in alpha development status and changes. We currently recommend using the stable
                      <BLink href="https://www.sysid.dbmr.unibe.ch/" target="_blank">SysID database</BLink>
                      for your work until a more stable beta status is reached.
                    </p>
                  </div>
                </div>
              </div>
            </BAccordionItem>

            <BAccordionItem title="Credits and acknowledgement">
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-award me-2" />
                  Credits and acknowledgement
                </span>
              </template>
              <div class="py-2">
                <p>
                  We acknowledge Martijn Huynen and members of the Huynen and Schenck groups at the Radboud
                  University Medical Center Nijmegen, The Netherlands, for building SysID and supporting it
                  for many years.
                </p>
                <p>
                  We would also like to thank all past users for using SysID and for constructive feedback,
                  thus making the sometimes tedious updates and re-organization into the new SysNDD database
                  worthwhile.
                </p>
                <p>
                  Since recently, Alain Verloes and ERN ITHACA provide valuable encouragement and support by
                  initiating and supporting the data integration with Orphanet and helping with the recruitment
                  of expert curators.
                </p>
              </div>
            </BAccordionItem>

            <BAccordionItem title="Disclaimer">
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-shield-exclamation me-2" />
                  Disclaimer
                </span>
              </template>
              <div class="py-2">
                <BAlert
                  variant="warning"
                  show
                  class="mb-3"
                >
                  The Department of Human Genetics (University Hospital, University Bern, Bern, Switzerland)
                  makes no representation about the suitability or accuracy of this software or data for any
                  purpose, and makes no warranties, including fitness for a particular purpose or that the use
                  of this software will not infringe any third party patents, copyrights, trademarks or other rights.
                </BAlert>

                <BListGroup flush>
                  <BListGroupItem class="bg-transparent">
                    <strong>Responsible for this website:</strong><br>
                    Bernt Popp (admin [at] sysndd.org)
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <strong>Responsible for this project:</strong><br>
                    Christiane Zweier (curator [at] sysndd.org)
                  </BListGroupItem>
                  <BListGroupItem class="bg-transparent">
                    <strong>Address:</strong><br>
                    Universitatsklinik fur Humangenetik, Inselspital, Universitatsspital Bern,
                    Freiburgstrasse 15, 3010 Bern, Switzerland
                  </BListGroupItem>
                </BListGroup>
              </div>
            </BAccordionItem>

            <BAccordionItem title="Contact">
              <template #title>
                <span class="fw-semibold">
                  <i class="bi bi-envelope me-2" />
                  Contact
                </span>
              </template>
              <div class="py-2">
                <BCard
                  class="text-center border-0 bg-light"
                  body-class="py-4"
                >
                  <i class="bi bi-envelope-at fs-1 text-primary mb-3 d-block" />
                  <p class="mb-2">
                    If you have technical problems using SysNDD or requests regarding the data or functionality,
                    please contact us at:
                  </p>
                  <p class="fw-bold text-primary fs-5 mb-0">
                    support [at] sysndd.org
                  </p>
                </BCard>
              </div>
            </BAccordionItem>
          </BAccordion>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useHead } from '@unhead/vue';
import { renderMarkdown } from '@/composables';
import type { AboutSection } from '@/types';
import axios from 'axios';

useHead({
  title: 'About',
  meta: [
    {
      name: 'description',
      content:
        'The About view contains information about the SysNDD curation effort and website.',
    },
  ],
});

const loading = ref(true);
const useCmsContent = ref(false);
const cmsContent = ref<AboutSection[]>([]);

const API_URL = import.meta.env.VITE_API_URL || '';

onMounted(async () => {
  try {
    // Try to load CMS content from API
    const response = await axios.get<{ sections: AboutSection[] } | AboutSection[]>(
      `${API_URL}/api/about/published`,
      { timeout: 5000 }
    );

    // Handle different response formats
    let sections: AboutSection[] = [];
    if (Array.isArray(response.data)) {
      sections = response.data;
    } else if (response.data && 'sections' in response.data) {
      sections = response.data.sections || [];
    }

    if (sections.length > 0) {
      cmsContent.value = sections;
      useCmsContent.value = true;
    }
    // If no CMS content, fallback to hardcoded content (useCmsContent stays false)
  } catch (_err) {
    // API not available or error - use default hardcoded content
    console.log('CMS content not available, using default content');
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.bg-light {
  background-color: #f8f9fa !important;
}

.border-4 {
  border-width: 4px !important;
}

.timeline .d-flex {
  border-left: 2px solid #dee2e6;
  padding-left: 1rem;
  margin-left: 0.5rem;
}

.timeline .d-flex:last-child {
  border-left-color: transparent;
}

/* Markdown content styling for CMS content */
.about-content :deep(h1),
.about-content :deep(h2),
.about-content :deep(h3),
.about-content :deep(h4),
.about-content :deep(h5),
.about-content :deep(h6) {
  margin-top: 1rem;
  margin-bottom: 0.5rem;
  font-weight: 600;
}

.about-content :deep(p) {
  margin-bottom: 0.75rem;
}

.about-content :deep(ul),
.about-content :deep(ol) {
  padding-left: 1.5rem;
  margin-bottom: 0.75rem;
}

.about-content :deep(a) {
  color: var(--bs-primary);
}

.about-content :deep(blockquote) {
  border-left: 4px solid var(--bs-primary);
  padding-left: 1rem;
  margin-left: 0;
  color: var(--bs-secondary);
}

.about-content :deep(code) {
  background: #f4f4f4;
  padding: 0.125rem 0.25rem;
  border-radius: 0.25rem;
}

.about-content :deep(pre) {
  background: #f4f4f4;
  padding: 1rem;
  border-radius: 0.375rem;
  overflow-x: auto;
}
</style>
