<!-- src/views/analyses/GeneNetworks.vue -->
<template>
  <div class="container-fluid">
    <b-container fluid>
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="12"
        >
          <div>
            <b-tab
              title="Functional clusters"
              active
            >
              <AnalyseGeneClusters />
            </b-tab>
          </div>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import toastMixin from '@/assets/js/mixins/toastMixin';

export default {
  name: 'GeneNetworks',
  mixins: [toastMixin],
  setup() {
    useHead({
      title: 'Functional clusters',
      meta: [
        {
          name: 'description',
          content:
            'The Gene Networks analysis shows the interactions between genes associated with neurodevelopmental disorders and curated in SysNDD.',
        },
      ],
    });
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
