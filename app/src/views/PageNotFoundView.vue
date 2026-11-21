<template>
  <!-- login-page gives the canvas without .public-page link colours, which would recolour the buttons. -->
  <div class="login-page">
    <div class="public-shell not-found">
      <section class="public-panel not-found__panel" aria-labelledby="not-found-title">
        <p class="not-found__code" aria-hidden="true">404</p>
        <h1 id="not-found-title" class="public-title">Page not found</h1>
        <p class="public-description">
          The address may be mistyped, or the page has moved. Start again from the home page or
          browse the curated entities and genes.
        </p>
        <nav class="not-found__links" aria-label="Ways forward">
          <RouterLink to="/" class="btn btn-primary">Go to home</RouterLink>
          <RouterLink to="/Entities" class="btn btn-outline-secondary">Browse entities</RouterLink>
          <RouterLink to="/Genes" class="btn btn-outline-secondary">Browse genes</RouterLink>
        </nav>
      </section>
    </div>
  </div>
</template>

<script>
export default {
  name: 'PageNotFoundView',
};
</script>

<style scoped>
.not-found {
  width: min(100%, 40rem);
  padding-top: clamp(1rem, 8vh, 4rem);
}

.not-found__panel {
  padding: 1.5rem;
}

.not-found__code {
  margin: 0 0 0.25rem;
  color: var(--neutral-700, #616161);
  font-size: 1rem;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

.not-found__links {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 1.25rem;
}
</style>
