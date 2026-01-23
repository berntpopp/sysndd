<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="12"
        >
          <!-- Include TablesLogs Component Here -->
          <TablesLogs
            :sort-input="sort"
            :filter-input="filter"
            :fields-input="fields"
            :page-after-input="pageAfter"
            :page-size-input="pageSize"
            :fspec-input="fspec"
          />
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';

export default {
  name: 'ViewLogs',
  props: {
    sort: { type: String, default: '-id' },
    filter: { type: String, default: null },
    fields: { type: String, default: null },
    pageAfter: { type: String, default: '0' },
    pageSize: { type: Number, default: 10 },
    fspec: {
      type: String,
      default:
        'id,timestamp,address,agent,host,request_method,path,query,post,status,duration,file,modified',
    },
  },
  setup() {
    useHead({
      title: 'Logging',
      meta: [
        {
          name: 'description',
          content: 'An expert curated resource of neurodevelopmental disorders.',
        },
      ],
    });
  },
};
</script>

<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
</style>
