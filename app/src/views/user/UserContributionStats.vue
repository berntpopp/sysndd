<template>
  <section class="contribution-grid" aria-label="User contribution counts">
    <article class="stat-card stat-card--reviews">
      <span class="stat-icon" aria-hidden="true">
        <i class="bi bi-journal-check" />
      </span>
      <strong>{{ activeReviews }}</strong>
      <span>Active Reviews</span>
    </article>
    <article class="stat-card stat-card--status">
      <span class="stat-icon" aria-hidden="true">
        <i class="bi bi-check2-square" />
      </span>
      <strong>{{ activeStatus }}</strong>
      <span>Status Contributions</span>
    </article>
  </section>
</template>

<script setup lang="ts">
defineProps<{
  activeReviews: number;
  activeStatus: number;
}>();
</script>

<style scoped>
.contribution-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.85rem;
}

.stat-card {
  display: grid;
  justify-items: center;
  gap: 0.25rem;
  padding: 1rem;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.08);
}

.stat-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 999px;
  font-size: 1.1rem;
}

.stat-card--reviews .stat-icon {
  background: #e8f1ff;
  color: #0d6efd;
}

.stat-card--status .stat-icon {
  background: #e6f5ee;
  color: #198754;
}

.stat-card strong {
  color: #172033;
  font-size: 1.45rem;
  line-height: 1.1;
}

.stat-card span:last-child {
  color: #526070;
  font-size: 0.84rem;
}
</style>
