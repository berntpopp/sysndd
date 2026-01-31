<template>
  <div class="container-fluid bg-gradient">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <AnalysesTimePlot />
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import useToast from '@/composables/useToast';
import AnalysesTimePlot from '@/components/analyses/AnalysesTimePlot.vue';

export default {
  name: 'EntriesOverTime',
  components: {
    AnalysesTimePlot,
  },
  setup() {
    const { makeToast } = useToast();
    useHead({
      title: 'Entries over time',
      meta: [
        {
          name: 'description',
          content:
            'This analysis shows the development of database entries over time for neurodevelopmental disorders curated in SysNDD.',
        },
      ],
    });

    return { makeToast };
  },
  data() {
    return {
      tabIndex: 0,
    };
  },
  mounted() {},
  methods: {},
};
</script>

<style scoped></style>
