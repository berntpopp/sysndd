<template>
  <AnalysisShell
    title="NDD entities and genes over time"
    subtitle="Track curated SysNDD entities and genes across update years."
  >
    <AnalysesTimePlot />
  </AnalysisShell>
</template>

<script>
import { useHead } from '@unhead/vue';
import useToast from '@/composables/useToast';
import AnalysesTimePlot from '@/components/analyses/AnalysesTimePlot.vue';
import AnalysisShell from '@/components/analyses/AnalysisShell.vue';

export default {
  name: 'EntriesOverTime',
  components: {
    AnalysisShell,
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
