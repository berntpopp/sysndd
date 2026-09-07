<!-- src/components/gene/ProteinLollipopSkeleton.vue -->
<!--
  Loading skeleton for ProteinDomainLollipopPlot.
  Renders a placeholder plot area and controls strip matching the dimensions
  of the resolved lollipop visualization to eliminate Cumulative Layout Shift (CLS)
  and prevent flashes of the empty state while ClinVar and UniProt data are loading.
-->
<template>
  <div
    class="protein-lollipop-skeleton"
    role="status"
    aria-live="polite"
    aria-label="Loading protein domain and variant visualization"
  >
    <span class="visually-hidden">Loading protein domain and variant visualization...</span>

    <!-- Plot area skeleton -->
    <div class="skeleton-plot-area">
      <!-- Lollipop stems & markers placeholder -->
      <div class="skeleton-stems-container" aria-hidden="true">
        <div
          v-for="(stem, idx) in STEM_CONFIGS"
          :key="idx"
          class="skeleton-stem-wrapper"
          :style="{ left: stem.left, height: stem.height }"
        >
          <div class="skeleton-marker skeleton-shimmer" :class="{ 'skeleton-marker--diamond': stem.diamond }" />
          <div class="skeleton-stem skeleton-shimmer" />
        </div>
      </div>

      <!-- Protein backbone placeholder -->
      <div class="skeleton-backbone-wrapper" aria-hidden="true">
        <div class="skeleton-backbone skeleton-shimmer">
          <!-- Domain block highlights -->
          <div class="skeleton-domain skeleton-domain--1" />
          <div class="skeleton-domain skeleton-domain--2" />
          <div class="skeleton-domain skeleton-domain--3" />
        </div>
      </div>

      <!-- Amino acid scale placeholder -->
      <div class="skeleton-axis-wrapper" aria-hidden="true">
        <div class="skeleton-axis-line skeleton-shimmer" />
        <div class="skeleton-axis-labels">
          <span class="skeleton-axis-label">1</span>
          <span class="skeleton-axis-label">500</span>
          <span class="skeleton-axis-label">1000</span>
          <span class="skeleton-axis-label">1500</span>
        </div>
      </div>
    </div>

    <!-- Controls strip skeleton -->
    <div class="skeleton-controls-strip" aria-hidden="true">
      <div class="skeleton-btn-group skeleton-shimmer" />
      <div class="skeleton-chips-row">
        <div class="skeleton-chip skeleton-shimmer" style="width: 80px;" />
        <div class="skeleton-chip skeleton-shimmer" style="width: 105px;" />
        <div class="skeleton-chip skeleton-shimmer" style="width: 65px;" />
        <div class="skeleton-chip skeleton-shimmer" style="width: 75px;" />
      </div>
      <div class="skeleton-export-group">
        <div class="skeleton-btn skeleton-shimmer" style="width: 48px;" />
        <div class="skeleton-btn skeleton-shimmer" style="width: 48px;" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const STEM_CONFIGS = [
  { left: '12%', height: '70px', diamond: false },
  { left: '18%', height: '95px', diamond: true },
  { left: '26%', height: '50px', diamond: false },
  { left: '38%', height: '110px', diamond: false },
  { left: '44%', height: '65px', diamond: true },
  { left: '55%', height: '85px', diamond: false },
  { left: '62%', height: '105px', diamond: false },
  { left: '71%', height: '60px', diamond: true },
  { left: '80%', height: '90px', diamond: false },
  { left: '88%', height: '75px', diamond: false },
];
</script>

<style scoped>
.protein-lollipop-skeleton {
  width: 100%;
  max-width: 1400px;
  margin: 0 auto;
  padding: 12px 16px;
  min-height: 290px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.skeleton-shimmer {
  background: linear-gradient(90deg, #eef2f7 25%, #f8fafc 37%, #eef2f7 63%);
  background-size: 400% 100%;
  animation: lollipop-skeleton-shimmer 1.4s ease infinite;
}

@keyframes lollipop-skeleton-shimmer {
  0% {
    background-position: 100% 50%;
  }
  100% {
    background-position: 0% 50%;
  }
}

/* Plot area */
.skeleton-plot-area {
  position: relative;
  height: 200px;
  width: 100%;
  margin-bottom: 8px;
}

.skeleton-stems-container {
  position: absolute;
  top: 10px;
  left: 20px;
  right: 20px;
  height: 120px;
}

.skeleton-stem-wrapper {
  position: absolute;
  bottom: 0;
  width: 14px;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.skeleton-marker {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
  margin-bottom: -1px;
}

.skeleton-marker--diamond {
  border-radius: 2px;
  transform: rotate(45deg);
  width: 8px;
  height: 8px;
}

.skeleton-stem {
  width: 2px;
  flex: 1;
}

.skeleton-backbone-wrapper {
  position: absolute;
  top: 130px;
  left: 20px;
  right: 20px;
  height: 24px;
}

.skeleton-backbone {
  width: 100%;
  height: 100%;
  border-radius: 6px;
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(15, 23, 42, 0.06);
}

.skeleton-domain {
  position: absolute;
  top: 2px;
  bottom: 2px;
  border-radius: 4px;
  background: rgba(13, 110, 253, 0.12);
}

.skeleton-domain--1 {
  left: 15%;
  width: 18%;
}

.skeleton-domain--2 {
  left: 42%;
  width: 22%;
}

.skeleton-domain--3 {
  left: 72%;
  width: 16%;
}

.skeleton-axis-wrapper {
  position: absolute;
  top: 160px;
  left: 20px;
  right: 20px;
}

.skeleton-axis-line {
  width: 100%;
  height: 2px;
  border-radius: 1px;
  margin-bottom: 4px;
}

.skeleton-axis-labels {
  display: flex;
  justify-content: space-between;
  font-size: 0.68rem;
  color: #adb5bd;
}

/* Controls strip */
.skeleton-controls-strip {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 8px;
  padding-top: 10px;
  border-top: 1px solid #f1f3f5;
}

.skeleton-btn-group {
  width: 130px;
  height: 26px;
  border-radius: 4px;
}

.skeleton-chips-row {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.skeleton-chip {
  height: 24px;
  border-radius: 12px;
}

.skeleton-export-group {
  display: flex;
  gap: 4px;
}

.skeleton-btn {
  height: 26px;
  border-radius: 4px;
}

@media (max-width: 768px) {
  .protein-lollipop-skeleton {
    padding: 8px 6px;
    min-height: 260px;
  }
  .skeleton-controls-strip {
    flex-direction: column;
    align-items: stretch;
  }
  .skeleton-btn-group {
    width: 100%;
  }
  .skeleton-export-group {
    justify-content: flex-end;
  }
}
</style>
