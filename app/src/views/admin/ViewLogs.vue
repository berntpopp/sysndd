<template>
  <div class="container-fluid">
    <b-container fluid>
      <b-row class="justify-content-md-center py-2">
        <b-col
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
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>

export default {
  name: 'ViewLogs',
  props: {
    sort: { type: String, default: '+row_id' },
    filter: { type: String, default: null },
    fields: { type: String, default: null },
    pageAfter: { type: String, default: '0' },
    pageSize: { type: String, default: '10' },
    fspec: {
      type: String,
      default:
        'row_id,remote_addr,http_user_agent,http_host,request_method,path_info,query_string,postbody,status,duration,filename,last_modified',
    },
  },
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Logging',
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
        content: 'An expert curated resource of neurodevelopmental disorders.',
      },
    ],
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
