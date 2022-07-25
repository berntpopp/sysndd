<template>
  <div class="container-fluid">
    <b-container fluid>
      Content coming
    </b-container>
  </div>
</template>

<script>
export default {
  name: 'PublicationsNDD',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'NDD publications',
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
          'The NDD Publications analysis shows conent of publicatins reviewed in the SysNDD database.',
      },
    ],
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
