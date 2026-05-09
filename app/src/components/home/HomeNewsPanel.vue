<template>
  <section class="home-panel home-news-panel" aria-labelledby="home-news-title">
    <header class="home-panel__header">
      <div>
        <h2 id="home-news-title" class="home-panel__title">New entities</h2>
        <p class="home-panel__description">Recently added curated gene-disease relationships.</p>
      </div>
      <BLink to="/Entities?sort=-entry_date&page_size=10" class="home-panel__link">
        Browse all
      </BLink>
    </header>

    <div class="home-news-table-wrap d-none d-md-block">
      <table class="home-news-table">
        <thead>
          <tr>
            <th scope="col">Entity</th>
            <th scope="col">Gene</th>
            <th scope="col">Disease</th>
            <th scope="col">Inh.</th>
            <th scope="col">Class</th>
            <th scope="col">NDD</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in news" :key="item.entity_id">
            <td>
              <EntityBadge
                :entity-id="item.entity_id"
                :link-to="`/Entities/${item.entity_id}`"
                :title="`Entry date: ${item.entry_date}`"
                size="sm"
              />
            </td>
            <td>
              <GeneBadge
                :symbol="item.symbol"
                :hgnc-id="String(item.hgnc_id)"
                :link-to="`/Genes/${item.hgnc_id}`"
                size="sm"
              />
            </td>
            <td>
              <DiseaseBadge
                :name="item.disease_ontology_name"
                :ontology-id="item.disease_ontology_id_version"
                :link-to="`/Ontology/${item.disease_ontology_id_version}`"
                :max-length="32"
                size="sm"
              />
            </td>
            <td>
              <InheritanceBadge
                :full-name="item.inheritance_filter"
                :hpo-term="item.hpo_mode_of_inheritance_term"
                size="sm"
              />
            </td>
            <td>
              <CategoryIcon :category="item.category" size="sm" :show-title="false" />
            </td>
            <td>
              <NddIcon :status="item.ndd_phenotype_word" size="sm" :show-title="false" />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="home-news-list d-md-none">
      <article v-for="item in news" :key="item.entity_id" class="home-news-item">
        <div class="home-news-item__main">
          <EntityBadge
            :entity-id="item.entity_id"
            :link-to="`/Entities/${item.entity_id}`"
            :title="`Entry date: ${item.entry_date}`"
            size="sm"
          />
          <GeneBadge
            :symbol="item.symbol"
            :hgnc-id="String(item.hgnc_id)"
            :link-to="`/Genes/${item.hgnc_id}`"
            size="sm"
          />
        </div>
        <DiseaseBadge
          :name="item.disease_ontology_name"
          :ontology-id="item.disease_ontology_id_version"
          :link-to="`/Ontology/${item.disease_ontology_id_version}`"
          :max-length="42"
          size="sm"
        />
        <div class="home-news-item__meta">
          <InheritanceBadge
            :full-name="item.inheritance_filter"
            :hpo-term="item.hpo_mode_of_inheritance_term"
            size="sm"
          />
          <CategoryIcon :category="item.category" size="sm" :show-title="false" />
          <NddIcon :status="item.ndd_phenotype_word" size="sm" :show-title="false" />
        </div>
      </article>
    </div>
  </section>
</template>

<script setup lang="ts">
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

interface NewsItem {
  entity_id: string | number;
  symbol: string;
  hgnc_id: string | number;
  disease_ontology_name: string;
  disease_ontology_id_version: string;
  inheritance_filter: string;
  hpo_mode_of_inheritance_term: string;
  category: string;
  ndd_phenotype_word: string;
  entry_date: string;
}

defineProps<{
  news: NewsItem[];
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
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
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

.home-panel__link {
  flex: 0 0 auto;
  color: #244b7a;
  font-size: 0.8125rem;
  font-weight: 700;
  text-decoration: none;
}

.home-news-table-wrap {
  padding: 0.75rem 1rem 1rem;
}

.home-news-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}

.home-news-table th {
  padding: 0.45rem 0.35rem;
  border-bottom: 1px solid #d8e0ea;
  background: #f6f8fb;
  color: #172033;
  font-weight: 700;
}

.home-news-table td {
  padding: 0.45rem 0.35rem;
  border-bottom: 1px solid #edf1f5;
  vertical-align: middle;
}

.home-news-list {
  display: grid;
  gap: 0.55rem;
  padding: 0.75rem;
}

.home-news-item {
  display: grid;
  gap: 0.45rem;
  padding: 0.65rem;
  border: 1px solid #e1e7ef;
  border-radius: 8px;
  background: #fff;
}

.home-news-item__main,
.home-news-item__meta {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  align-items: center;
}

.home-news-panel :deep(.entity-badge-link),
.home-news-panel :deep(.gene-badge-link),
.home-news-panel :deep(.disease-badge-link),
.home-news-panel :deep(.inheritance-badge-link) {
  transition:
    transform 0.14s ease,
    box-shadow 0.14s ease,
    filter 0.14s ease;
}

.home-news-panel :deep(.entity-badge-link:hover),
.home-news-panel :deep(.entity-badge-link:focus),
.home-news-panel :deep(.gene-badge-link:hover),
.home-news-panel :deep(.gene-badge-link:focus),
.home-news-panel :deep(.disease-badge-link:hover),
.home-news-panel :deep(.disease-badge-link:focus),
.home-news-panel :deep(.inheritance-badge-link:hover),
.home-news-panel :deep(.inheritance-badge-link:focus) {
  box-shadow: 0 0.35rem 0.8rem rgba(15, 23, 42, 0.14);
  filter: brightness(1.04);
  transform: translateY(-1px);
}

@media (prefers-reduced-motion: reduce) {
  .home-news-panel :deep(.entity-badge-link),
  .home-news-panel :deep(.gene-badge-link),
  .home-news-panel :deep(.disease-badge-link),
  .home-news-panel :deep(.inheritance-badge-link) {
    transition: none;
  }

  .home-news-panel :deep(.entity-badge-link:hover),
  .home-news-panel :deep(.entity-badge-link:focus),
  .home-news-panel :deep(.gene-badge-link:hover),
  .home-news-panel :deep(.gene-badge-link:focus),
  .home-news-panel :deep(.disease-badge-link:hover),
  .home-news-panel :deep(.disease-badge-link:focus),
  .home-news-panel :deep(.inheritance-badge-link:hover),
  .home-news-panel :deep(.inheritance-badge-link:focus) {
    transform: none;
  }
}

@media (max-width: 575.98px) {
  .home-panel__header {
    flex-direction: column;
    gap: 0.5rem;
    padding: 0.75rem;
  }
}
</style>
