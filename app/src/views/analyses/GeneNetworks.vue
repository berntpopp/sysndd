<!-- src/views/analyses/GeneNetworks.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="12"
        >
          <div>
            <BTab
              title="Functional clusters"
              active
            >
              <AnalyseGeneClusters />
            </BTab>
          </div>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import useToast from '@/composables/useToast';
import AnalyseGeneClusters from '@/components/analyses/AnalyseGeneClusters.vue';

export default {
  name: 'GeneNetworks',
  components: {
    AnalyseGeneClusters,
  },
  setup() {
    const { makeToast } = useToast();
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

    return { makeToast };
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
