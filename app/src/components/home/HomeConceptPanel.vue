<template>
  <section class="home-panel home-concept-panel" aria-labelledby="home-concepts-title">
    <header class="home-panel__header">
      <div>
        <h2 id="home-concepts-title" class="home-panel__title">How SysNDD is organized</h2>
        <p class="home-panel__description">Core data concepts used throughout the application.</p>
      </div>
    </header>

    <div class="home-concept-body">
      <div class="home-concept-callout">
        <span class="home-concept-kicker">Entity</span>
        <div class="entity-concept__container">
          <GeneBadge symbol="Gene" :show-title="false" size="sm" />
          <InheritanceBadge
            full-name="Inheritance"
            :show-title="false"
            :use-abbreviation="false"
            size="sm"
          />
          <DiseaseBadge name="Disease" :show-title="false" :max-length="0" size="sm" />
        </div>
        <p>
          SysNDD stores immutable gene-inheritance-disease units rather than only gene-level
          records.
        </p>
      </div>

      <div class="home-concept-section">
        <h3>Neurodevelopmental disorders</h3>
        <p>
          NDD include developmental delay, intellectual disability and autism spectrum disorder.
          They are clinically and genetically heterogeneous and affect about 2% of newborns.
        </p>
      </div>

      <div class="home-concept-section">
        <h3>Classification</h3>
        <p>
          Entity categories summarize the strength of association with NDD phenotypes. Panel views
          aggregate by gene and use the highest associated entity category.
        </p>
        <div class="home-category-strip">
          <span><CategoryIcon category="Definitive" />Definitive</span>
          <span><CategoryIcon category="Moderate" />Moderate</span>
          <span><CategoryIcon category="Limited" />Limited</span>
          <span><CategoryIcon category="Refuted" />Refuted</span>
        </div>
      </div>

      <div class="home-concept-section">
        <h3>What you can do</h3>
        <p>
          Browse curated entities, download table views, inspect gene pages, and compare SysNDD
          coverage with external curation efforts.
        </p>
        <div class="home-action-links">
          <BLink to="/Entities?sort=%2Bentity_id&page_size=10">Entities</BLink>
          <BLink to="/Genes?sort=%2Bsymbol&page_size=10">Genes</BLink>
          <BLink to="/CurationComparisons">Comparisons</BLink>
          <BLink :href="docsUrl" target="_blank">Documentation</BLink>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

defineProps<{
  docsUrl: string;
}>();
</script>

<style scoped>
.home-panel {
  overflow: hidden;
  border: 1px solid #d9e0ea;
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.08);
}

.home-panel__header {
  padding: 0.85rem 1rem 0.7rem;
  border-bottom: 1px solid #e6ebf2;
  background: #fbfcfe;
}

.home-panel__title {
  margin: 0;
  color: #172033;
  font-size: 1.05rem;
  font-weight: 700;
  line-height: 1.2;
}

.home-panel__description {
  margin: 0.25rem 0 0;
  color: #526070;
  font-size: 0.875rem;
  line-height: 1.35;
}

.home-concept-body {
  display: grid;
  gap: 1rem;
  padding: 1rem;
}

.home-concept-callout {
  display: grid;
  gap: 0.55rem;
  padding: 0.85rem;
  border: 1px solid #d8e0ea;
  border-radius: 8px;
  background: #f8fafc;
}

.home-concept-kicker {
  color: #244b7a;
  font-size: 0.75rem;
  font-weight: 800;
  letter-spacing: 0;
  text-transform: uppercase;
}

.entity-concept__container,
.home-category-strip,
.home-action-links {
  display: flex;
  flex-wrap: wrap;
  gap: 0.45rem;
  align-items: center;
}

.home-concept-callout p,
.home-concept-section p {
  margin: 0;
  color: #344054;
  font-size: 0.925rem;
  line-height: 1.5;
}

.home-concept-section {
  display: grid;
  gap: 0.45rem;
}

.home-concept-section h3 {
  margin: 0;
  color: #27364a;
  font-size: 0.95rem;
  font-weight: 700;
}

.home-category-strip span {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  color: #344054;
  font-size: 0.8125rem;
  font-weight: 700;
}

.home-action-links a {
  display: inline-flex;
  align-items: center;
  min-height: 1.75rem;
  padding: 0.25rem 0.6rem;
  border: 1px solid #c7d3e2;
  border-radius: 999px;
  background: #fff;
  color: #244b7a;
  font-size: 0.8125rem;
  font-weight: 700;
  text-decoration: none;
  transition:
    transform 0.14s ease,
    border-color 0.14s ease,
    box-shadow 0.14s ease,
    background-color 0.14s ease;
}

.home-action-links a:hover,
.home-action-links a:focus {
  border-color: #0f172a;
  background: #fff;
  box-shadow: 0 0.35rem 0.8rem rgba(15, 23, 42, 0.14);
  color: #0f172a;
  outline: none;
  transform: translateY(-1px);
}

.home-action-links a:focus-visible {
  box-shadow:
    0 0 0 0.16rem rgba(13, 110, 253, 0.22),
    0 0.35rem 0.8rem rgba(15, 23, 42, 0.14);
}

.home-concept-panel :deep(.gene-badge-link),
.home-concept-panel :deep(.disease-badge-link),
.home-concept-panel :deep(.inheritance-badge-link) {
  transition:
    transform 0.14s ease,
    box-shadow 0.14s ease,
    filter 0.14s ease;
}

.home-concept-panel :deep(.gene-badge-link:hover),
.home-concept-panel :deep(.gene-badge-link:focus),
.home-concept-panel :deep(.disease-badge-link:hover),
.home-concept-panel :deep(.disease-badge-link:focus),
.home-concept-panel :deep(.inheritance-badge-link:hover),
.home-concept-panel :deep(.inheritance-badge-link:focus) {
  box-shadow: 0 0.35rem 0.8rem rgba(15, 23, 42, 0.14);
  filter: brightness(1.04);
  transform: translateY(-1px);
}

@media (prefers-reduced-motion: reduce) {
  .home-action-links a,
  .home-concept-panel :deep(.gene-badge-link),
  .home-concept-panel :deep(.disease-badge-link),
  .home-concept-panel :deep(.inheritance-badge-link) {
    transition: none;
  }

  .home-action-links a:hover,
  .home-action-links a:focus,
  .home-concept-panel :deep(.gene-badge-link:hover),
  .home-concept-panel :deep(.gene-badge-link:focus),
  .home-concept-panel :deep(.disease-badge-link:hover),
  .home-concept-panel :deep(.disease-badge-link:focus),
  .home-concept-panel :deep(.inheritance-badge-link:hover),
  .home-concept-panel :deep(.inheritance-badge-link:focus) {
    transform: none;
  }
}
</style>
