<!-- src/views/help/AboutView.vue -->
<!--
  Audit improvements (7→9):
  A. h1 painted first (LCP fix): shell renders immediately; CMS fetch is
     backgrounded so "About SysNDD" h1 is the LCP element, not the API response.
  B. Heading order: accordion titles promoted to h2, "Affiliations" to h3.
  C. Decorative cards removed: Contact BCard → plain paragraph+mono link;
     Citation BCard border-4 → plain <ol>; #dee2e6/#f4f4f4 → token vars.
  D. Color-only status: News badges gain text type labels; funding icons
     gain aria-label distinguishing current vs previous.
-->
<template>
  <div class="public-page about-page">
    <!--
      Shell and hero render immediately (loading state removed from the
      outer wrapper) so the h1 is the LCP element, not gated on CMS fetch.
    -->
    <div class="public-shell">
      <!-- Page Header — paints on first render, becomes LCP element -->
      <header class="public-hero">
        <div>
          <p class="public-kicker">Project context</p>
          <h1 class="public-title">
            <i class="bi bi-info-circle me-2" aria-hidden="true" />
            About SysNDD
          </h1>
          <p class="public-description">
            Learn about the SysNDD database, its creators, funding, citation policy, and contact
            information.
          </p>
        </div>
      </header>

      <section class="public-panel" aria-label="About SysNDD content">
        <!-- CMS content loading indicator: shown only while fetch is in flight -->
        <div v-if="cmsLoading" class="about-cms-loading" role="status" aria-live="polite">
          <BSpinner small label="Loading content…" class="me-2" />
          <span class="text-muted">Loading…</span>
        </div>

        <!-- Dynamic Accordion from CMS (if available) -->
        <BAccordion v-if="useCmsContent && cmsContent.length > 0" id="about-accordion">
          <BAccordionItem
            v-for="(section, index) in cmsContent"
            :key="section.section_id"
            :visible="index === 0"
          >
            <template #title>
              <!-- h2 so the document outline is h1 → h2 with no skipped levels -->
              <h2 class="about-accordion-title">
                <i :class="section.icon + ' me-2'" aria-hidden="true" />
                {{ section.title }}
              </h2>
            </template>
            <div v-dompurify-html="renderMarkdown(section.content)" class="py-2 about-content" />
          </BAccordionItem>
        </BAccordion>

        <!-- Default Hardcoded Accordion (fallback or while loading) -->
        <BAccordion v-else id="about-accordion">

          <!-- ── About SysNDD and its creators ───────────────────── -->
          <BAccordionItem visible>
            <template #title>
              <h2 class="about-accordion-title">
                <i class="bi bi-people me-2" aria-hidden="true" />
                About SysNDD and its creators
              </h2>
            </template>
            <div class="py-2">
              <p>
                The SysNDD database is based on some content of its predecessor database, SysID
                (<BLink href="http://sysid.cmbi.umcn.nl/" target="_blank"
                  >http://sysid.cmbi.umcn.nl/</BLink
                >, more recently
                <BLink href="https://www.sysid.dbmr.unibe.ch/" target="_blank"
                  >https://www.sysid.dbmr.unibe.ch/</BLink
                >). The concept for a curated gene collection and database with the goal to
                facilitate research and diagnostics into NDDs has been conceived by Annette Schenck
                and Christiane Zweier.
              </p>
              <p>
                In 2009, they established SysID with a manually curated catalog of published genes
                implicated in neurodevelopmental disorders (NDDs), classified into primary and
                candidate genes according to the degree of underlying evidence. Furthermore, expert
                curated information on associated diseases and phenotypes was provided.
              </p>
              <p>
                Christiane Zweier has been updating SysID from its start in 2009. Together with her,
                Bernt Popp has now developed and programmed the new SysNDD database.
              </p>
              <p>
                To allow interoperability and mapping between gene-, phenotype- or disease-oriented
                databases, SysNDD is centered around curated gene-inheritance-disease units, so
                called entities, which are classified based on three evidence categories. This can
                account for the increased complexity of NDDs and allows to address a broader
                spectrum of diagnostic and research questions.
              </p>
              <p>
                Future functionality will be expanded to annotation of variant and network analyses.
                Another goal is to incorporate the SysID/SysNDD data into other
                gene/disease-relationship databases like the Orphanet Rare Disease ontology
                database.
              </p>

              <!-- h3 under the h2 accordion title — no heading levels skipped -->
              <h3 class="about-subheading mt-4 mb-3">
                <i class="bi bi-building me-2" aria-hidden="true" />
                Affiliations
              </h3>
              <BListGroup flush>
                <BListGroupItem class="bg-transparent">
                  <strong>Christiane Zweier:</strong> previously: Institute of Human Genetics,
                  University Hospital, FAU Erlangen, Germany; now: Human Genetics at the
                  University/University Hospital Bern, Switzerland
                </BListGroupItem>
                <BListGroupItem class="bg-transparent">
                  <strong>Bernt Popp:</strong> senior physician at the Berlin Institute of Health
                  (BIH) at Charite Berlin, Germany and scientist at the Institute of Human Genetics
                  at the University Hospital Leipzig, Germany
                </BListGroupItem>
                <BListGroupItem class="bg-transparent">
                  <strong>Annette Schenck:</strong> Radboud university medical center, Nijmegen, the
                  Netherlands
                </BListGroupItem>
              </BListGroup>
            </div>
          </BAccordionItem>

          <!-- ── Citation Policy ──────────────────────────────────── -->
          <BAccordionItem>
            <template #title>
              <h2 class="about-accordion-title">
                <i class="bi bi-journal-text me-2" aria-hidden="true" />
                Citation Policy
              </h2>
            </template>
            <div class="py-2">
              <!--
                Removed: <BCard class="mb-3 border-start border-primary border-4">
                Replace with a plain ordered list — quieter, no decorative border.
              -->
              <ol class="about-citation-list">
                <li>
                  <BLink href="https://pubmed.ncbi.nlm.nih.gov/26748517/" target="_blank">
                    Kochinke K, Zweier C, Nijhof B, Fenckova M, Cizek P, Honti F, Keerthikumar S,
                    Oortveld MA, Kleefstra T, Kramer JM, Webber C, Huynen MA, Schenck A. Systematic
                    Phenomics Analysis Deconvolutes Genes Mutated in Intellectual Disability into
                    Biologically Coherent Modules. Am J Hum Genet. 2016 Jan 7;98(1):149-64. doi:
                    10.1016/j.ajhg.2015.11.024. PMID: 26748517; PMCID: PMC4716705.
                  </BLink>
                </li>
              </ol>
              <p class="text-muted">
                Please cite the above publication. We are currently working on a new manuscript
                reporting SysNDD and the development of the NDD landscape over the past years. A
                link will be provided here upon publication.
              </p>
            </div>
          </BAccordionItem>

          <!-- ── Support and Funding ──────────────────────────────── -->
          <BAccordionItem>
            <template #title>
              <h2 class="about-accordion-title">
                <i class="bi bi-cash-stack me-2" aria-hidden="true" />
                Support and Funding
              </h2>
            </template>
            <div class="py-2">
              <h3 class="about-subheading mb-3">Current SysNDD database development is supported by:</h3>
              <BListGroup flush class="mb-4">
                <BListGroupItem class="bg-transparent">
                  <!--
                    aria-label distinguishes current (filled) from previous (outline) icon
                    so the status is not conveyed by fill-weight+color alone.
                  -->
                  <i
                    class="bi bi-check-circle-fill text-success me-2"
                    aria-label="Current funding"
                  />
                  DFG (Deutsche Forschungsgemeinschaft) grant PO2366/2-1 to
                  <BLink href="https://orcid.org/0000-0002-3679-1081" target="_blank"
                    >Bernt Popp</BLink
                  >
                </BListGroupItem>
                <BListGroupItem class="bg-transparent">
                  <i
                    class="bi bi-check-circle-fill text-success me-2"
                    aria-label="Current funding"
                  />
                  DFG (Deutsche Forschungsgemeinschaft) grant ZW184/6-1 to
                  <BLink href="https://orcid.org/0000-0001-8002-2020" target="_blank"
                    >Christiane Zweier</BLink
                  >
                </BListGroupItem>
                <BListGroupItem class="bg-transparent">
                  <i
                    class="bi bi-check-circle-fill text-success me-2"
                    aria-label="Current funding"
                  />
                  ITHACA ERN through
                  <BLink href="https://orcid.org/0000-0003-4819-0264" target="_blank"
                    >Alain Verloes</BLink
                  >
                </BListGroupItem>
              </BListGroup>

              <h3 class="about-subheading mb-3">Previous SysID database and data curation was supported by:</h3>
              <BListGroup flush>
                <BListGroupItem class="bg-transparent">
                  <i class="bi bi-check-circle text-secondary me-2" aria-label="Previous funding" />
                  The European Union's FP7 large scale integrated network GenCoDys (HEALTH-241995)
                  <BLink href="https://orcid.org/0000-0001-6189-5491" target="_blank">Martijn A Huynen</BLink>
                  and <BLink href="https://orcid.org/0000-0002-6918-3314" target="_blank">Annette Schenck</BLink>
                </BListGroupItem>
                <BListGroupItem class="bg-transparent">
                  <i class="bi bi-check-circle text-secondary me-2" aria-label="Previous funding" />
                  VIDI and TOP grants (917-96-346, 912-12-109) from The Netherlands Organisation for Scientific Research (NWO) to
                  <BLink href="https://orcid.org/0000-0002-6918-3314" target="_blank">Annette Schenck</BLink>
                </BListGroupItem>
                <BListGroupItem class="bg-transparent">
                  <i class="bi bi-check-circle text-secondary me-2" aria-label="Previous funding" />
                  DFG (Deutsche Forschungsgemeinschaft) grants ZW184/1-1 and -2 to
                  <BLink href="https://orcid.org/0000-0001-8002-2020" target="_blank">Christiane Zweier</BLink>
                </BListGroupItem>
                <BListGroupItem class="bg-transparent">
                  <i class="bi bi-check-circle text-secondary me-2" aria-label="Previous funding" />
                  the IZKF (Interdisziplinares Zentrum fur Klinische Forschung) Erlangen to
                  <BLink href="https://orcid.org/0000-0001-8002-2020" target="_blank">Christiane Zweier</BLink>
                </BListGroupItem>
                <BListGroupItem class="bg-transparent">
                  <i class="bi bi-check-circle text-secondary me-2" aria-label="Previous funding" />
                  ZonMw grant (NWO, 907-00-365) to
                  <BLink href="https://orcid.org/0000-0000-0956-0237" target="_blank">Tjitske Kleefstra</BLink>
                </BListGroupItem>
              </BListGroup>
            </div>
          </BAccordionItem>

          <!-- ── News and Updates ─────────────────────────────────── -->
          <BAccordionItem>
            <template #title>
              <h2 class="about-accordion-title">
                <i class="bi bi-megaphone me-2" aria-hidden="true" />
                News and Updates
              </h2>
            </template>
            <div class="py-2">
              <div class="about-timeline">
                <!--
                  News entries: date badge + text label so type is not
                  conveyed by variant color alone (audit: never-color-alone).
                  "Major update" vs "Update" gives AT and colorblind users
                  the same information as the primary vs secondary badge hue.
                -->
                <div class="about-timeline__entry">
                  <div class="about-timeline__badge-group">
                    <BBadge variant="primary" class="about-timeline__date">2022-05-07</BBadge>
                    <BBadge variant="primary" class="about-timeline__type">Major update</BBadge>
                  </div>
                  <p class="mb-0">
                    First SysNDD native data update. Deprecating SysID. SysNDD now in usable beta
                    mode.
                  </p>
                </div>
                <div class="about-timeline__entry">
                  <div class="about-timeline__badge-group">
                    <BBadge variant="secondary" class="about-timeline__date">2021-11-09</BBadge>
                    <BBadge variant="secondary" class="about-timeline__type">Update</BBadge>
                  </div>
                  <p class="mb-0">
                    Several updates to the APP, API and DB preparing it for re-review mode.
                  </p>
                </div>
                <div class="about-timeline__entry">
                  <div class="about-timeline__badge-group">
                    <BBadge variant="secondary" class="about-timeline__date">2021-08-16</BBadge>
                    <BBadge variant="secondary" class="about-timeline__type">Update</BBadge>
                  </div>
                  <p class="mb-0">
                    SysNDD is currently in alpha development status and changes. We currently
                    recommend using the stable
                    <BLink href="https://www.sysid.dbmr.unibe.ch/" target="_blank"
                      >SysID database</BLink
                    >
                    for your work until a more stable beta status is reached.
                  </p>
                </div>
              </div>
            </div>
          </BAccordionItem>

          <!-- ── Credits and acknowledgement ─────────────────────── -->
          <BAccordionItem>
            <template #title>
              <h2 class="about-accordion-title">
                <i class="bi bi-award me-2" aria-hidden="true" />
                Credits and acknowledgement
              </h2>
            </template>
            <div class="py-2">
              <p>
                We acknowledge Martijn Huynen and members of the Huynen and Schenck groups at the
                Radboud University Medical Center Nijmegen, The Netherlands, for building SysID and
                supporting it for many years.
              </p>
              <p>
                We would also like to thank all past users for using SysID and for constructive
                feedback, thus making the sometimes tedious updates and re-organization into the new
                SysNDD database worthwhile.
              </p>
              <p>
                Since recently, Alain Verloes and ERN ITHACA provide valuable encouragement and
                support by initiating and supporting the data integration with Orphanet and helping
                with the recruitment of expert curators.
              </p>
            </div>
          </BAccordionItem>

          <!-- ── Disclaimer ───────────────────────────────────────── -->
          <BAccordionItem>
            <template #title>
              <h2 class="about-accordion-title">
                <i class="bi bi-shield-exclamation me-2" aria-hidden="true" />
                Disclaimer
              </h2>
            </template>
            <div class="py-2">
              <BAlert variant="warning" show class="mb-3">
                The Department of Human Genetics (University Hospital, University Bern, Bern,
                Switzerland) makes no representation about the suitability or accuracy of this
                software or data for any purpose, and makes no warranties, including fitness for a
                particular purpose or that the use of this software will not infringe any third
                party patents, copyrights, trademarks or other rights.
              </BAlert>

              <BListGroup flush>
                <BListGroupItem class="bg-transparent">
                  <strong>Responsible for this website:</strong><br />
                  Bernt Popp (admin [at] sysndd.org)
                </BListGroupItem>
                <BListGroupItem class="bg-transparent">
                  <strong>Responsible for this project:</strong><br />
                  Christiane Zweier (curator [at] sysndd.org)
                </BListGroupItem>
                <BListGroupItem class="bg-transparent">
                  <strong>Address:</strong><br />
                  Universitatsklinik fur Humangenetik, Inselspital, Universitatsspital Bern,
                  Freiburgstrasse 15, 3010 Bern, Switzerland
                </BListGroupItem>
              </BListGroup>
            </div>
          </BAccordionItem>

          <!-- ── Contact ──────────────────────────────────────────── -->
          <BAccordionItem>
            <template #title>
              <h2 class="about-accordion-title">
                <i class="bi bi-envelope me-2" aria-hidden="true" />
                Contact
              </h2>
            </template>
            <div class="py-2">
              <!--
                Replaced the decorative <BCard class="text-center border-0 bg-light">
                with a quiet body-text paragraph and a monospace email link,
                matching the 'compact, no marketing decoration' clinical-tool intent.
              -->
              <p>
                If you have technical problems using SysNDD or requests regarding the data or
                functionality, please contact us at:
              </p>
              <p>
                <i class="bi bi-envelope me-1" aria-hidden="true" />
                <BLink href="mailto:support@sysndd.org" class="about-contact-email">
                  support [at] sysndd.org
                </BLink>
              </p>
            </div>
          </BAccordionItem>
        </BAccordion>

        <!-- Version information: App, API and Database (issue #22) -->
        <div class="d-flex justify-content-center mt-4">
          <AppVersionInfo />
        </div>
      </section>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useHead } from '@unhead/vue';
import { renderMarkdown } from '@/composables';
import type { AboutSection } from '@/types';
import { getPublishedAbout } from '@/api/about';
import AppVersionInfo from '@/components/AppVersionInfo.vue';

useHead({
  title: 'About',
  meta: [
    {
      name: 'description',
      content: 'The About view contains information about the SysNDD curation effort and website.',
    },
  ],
});

// Separate loading flag for the CMS fetch so the hero/h1 renders immediately.
// The outer shell is no longer gated on this flag.
const cmsLoading = ref(false);
const useCmsContent = ref(false);
const cmsContent = ref<AboutSection[]>([]);

onMounted(async () => {
  // Show a subtle inline loading indicator only for the accordion content,
  // not for the entire page — the h1 and hero text are already visible.
  cmsLoading.value = true;
  try {
    const data = await getPublishedAbout({ timeout: 5000, withCredentials: true });

    let sections: AboutSection[] = [];
    if (Array.isArray(data)) {
      sections = data as unknown as AboutSection[];
    } else if (data && typeof data === 'object' && 'sections' in data) {
      sections = (data as unknown as { sections?: AboutSection[] }).sections || [];
    }

    if (sections.length > 0) {
      cmsContent.value = sections;
      useCmsContent.value = true;
    }
  } catch (_err) {
    // CMS not available — fall back to hardcoded content silently
  } finally {
    cmsLoading.value = false;
  }
});
</script>

<style scoped>
/* ─── Accordion section title (h2 inside accordion button) ── */
/*
  Bootstrap's accordion-button applies its own font-size/weight. We reset
  the h2 margin and size so it inherits the button styling rather than
  competing with it. The element is h2 for semantic outline only; the
  visual treatment stays the same as the previous <span fw-semibold>.
*/
.about-accordion-title {
  margin: 0;
  font-size: inherit;
  font-weight: inherit;
  line-height: inherit;
  color: inherit;
}

/* ─── Sub-heading (h3) inside accordion body ─────────────── */
.about-subheading {
  font-size: 0.95rem;
  font-weight: 700;
  color: var(--neutral-800, #424242);
}

/* ─── Citation list ──────────────────────────────────────── */
.about-citation-list {
  padding-left: 1.25rem;
  margin-bottom: 0.75rem;
  color: var(--neutral-800, #424242);
  font-size: 0.93rem;
  line-height: 1.55;
}

.about-citation-list li {
  margin-bottom: 0.5rem;
}

/* ─── Contact email ──────────────────────────────────────── */
.about-contact-email {
  font-family: var(--font-family-mono, monospace);
  font-weight: 600;
  color: var(--medical-blue-700, #0d47a1);
}

/* ─── Timeline ───────────────────────────────────────────── */
.about-timeline {
  display: grid;
  gap: 1rem;
}

.about-timeline__entry {
  display: flex;
  gap: 0.75rem;
  align-items: flex-start;
  padding-left: 1rem;
  border-left: 2px solid var(--border-subtle, #d9e0ea);
  font-size: 0.93rem;
  line-height: 1.5;
}

/* Remove border from last entry (visual terminator) */
.about-timeline__entry:last-child {
  border-left-color: transparent;
}

.about-timeline__badge-group {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  flex: 0 0 auto;
}

.about-timeline__date,
.about-timeline__type {
  white-space: nowrap;
  font-size: 0.75rem;
}

/* ─── CMS loading indicator ──────────────────────────────── */
.about-cms-loading {
  display: flex;
  align-items: center;
  padding: 0.5rem 0 1rem;
  color: var(--neutral-600, #757575);
  font-size: 0.9rem;
}

/* ─── Markdown content styling for CMS accordion bodies ─── */
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
  color: var(--medical-blue-700, #0d47a1);
}

.about-content :deep(blockquote) {
  border-left: 4px solid var(--medical-blue-700, #0d47a1);
  padding-left: 1rem;
  margin-left: 0;
  color: var(--neutral-700, #616161);
}

/* Token-based code background: replaces hardcoded #f4f4f4 */
.about-content :deep(code) {
  background: var(--neutral-100, #f5f5f5);
  padding: 0.125rem 0.25rem;
  border-radius: 0.25rem;
  font-family: var(--font-family-mono, monospace);
}

.about-content :deep(pre) {
  background: var(--neutral-100, #f5f5f5);
  padding: 1rem;
  border-radius: 0.375rem;
  overflow-x: auto;
  border: 1px solid var(--border-subtle, #d9e0ea);
}
</style>
