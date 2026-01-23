<template>
  <div class="container-fluid centered">
    <BContainer>
      <BRow class="justify-content-md-center py-4">
        <BCol
          md="6"
          align-self="center"
        >
          <h1>404</h1>
          <h2>Page Not Found</h2>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
export default {
  name: 'PageNotFound',
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
.centered {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: calc(100vh - 100px);
}
</style>
