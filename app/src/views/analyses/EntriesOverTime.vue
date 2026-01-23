<template>
  <div class="container-fluid bg-gradient">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="12"
        >
          <AnalysesTimePlot />
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import toastMixin from '@/assets/js/mixins/toastMixin';

export default {
  name: 'EntriesOverTime',
  mixins: [toastMixin],
  setup() {
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

<style scoped>
</style>
