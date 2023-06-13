<template>
  <div class="container-fluid bg-gradient">
    <b-spinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <b-container
      v-else
      fluid
    >
      <b-row
        class="justify-content-md-center py-2"
        align-v="center"
      >
        <b-col
          col
          md="12"
        >
          <!-- Gene overview card -->
          <b-card
            header-tag="header"
            class="my-3 text-left"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h3 class="mb-1 text-left font-weight-bold">
                Gene:
                <b-badge
                  pill
                  variant="success"
                >
                  {{ $route.params.symbol }}
                </b-badge>
              </h3>
            </template>

            <b-table
              :items="gene"
              :fields="gene_fields"
              stacked
              small
            >
              <template #cell(symbol)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.symbol"
                    :key="id"
                  >
                    <b-col>
                      <div class="font-italic">
                        <b-link :href="'/Genes/' + id">
                          <b-badge
                            v-b-tooltip.hover.leftbottom
                            pill
                            variant="success"
                            class="mx-2"
                            :title="id"
                          >
                            {{ id }}
                          </b-badge>
                        </b-link>
                      </div>

                      <b-button
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="
                          'https://www.genenames.org/data/gene-symbol-report/#!/symbol/' +
                            id
                        "
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        <span class="font-italic"> {{ id }} </span>
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(name)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.name"
                    :key="id"
                  >
                    <b-col>
                      <span class="font-italic mx-2"> {{ id }} </span>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(entrez_id)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.entrez_id"
                    :key="id"
                  >
                    <b-col>
                      <b-button
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://www.ncbi.nlm.nih.gov/gene/' + id"
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(ensembl_gene_id)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.ensembl_gene_id"
                    :key="id"
                  >
                    <b-col>
                      <b-button
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="
                          'https://www.ensembl.org/Homo_sapiens/Gene/Summary?g=' +
                            id
                        "
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(ucsc_id)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.ucsc_id"
                    :key="id"
                  >
                    <b-col>
                      <b-button
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="
                          'https://genome-euro.ucsc.edu/cgi-bin/hgGene?hgg_gene=' +
                            id +
                            '&db=hg38'
                        "
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(ccds_id)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.ccds_id"
                    :key="id"
                  >
                    <b-col>
                      <b-button
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="
                          'https://www.ncbi.nlm.nih.gov/CCDS/CcdsBrowse.cgi?REQUEST=CCDS&DATA=' +
                            id
                        "
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(uniprot_ids)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.uniprot_ids"
                    :key="id"
                  >
                    <b-col>
                      <b-button
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://www.uniprot.org/uniprot/' + id"
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(omim_id)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.omim_id"
                    :key="id"
                  >
                    <b-col>
                      <b-button
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://www.omim.org/entry/' + id"
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        *{{ id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(mgd_id)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.mgd_id"
                    :key="id"
                  >
                    <b-col>
                      <b-button
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'http://www.informatics.jax.org/marker/' + id"
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(rgd_id)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.rgd_id"
                    :key="id"
                  >
                    <b-col>
                      <b-button
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="
                          'https://rgd.mcw.edu/rgdweb/report/gene/main.html?id=' +
                            id
                        "
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(STRING_id)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.STRING_id"
                    :key="id"
                  >
                    <b-col>
                      <b-button
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://string-db.org/network/' + id"
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>
            </b-table>
          </b-card>
          <!-- Gene overview card -->

          <!-- Associated entities table -->

          <TablesEntities
            v-if="gene.length !== 0"
            :show-filter-controls="false"
            :show-pagination-controls="false"
            header-label="Associated "
            :filter-input="'equals(symbol,' + gene[0].symbol + ')'"
          />

          <!-- Associated entities table -->
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';

// Import the utilities file
import Utils from '@/assets/js/utils';

export default {
  name: 'Gene',
  mixins: [toastMixin, colorAndSymbolsMixin],
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Gene',
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
        content: 'This Gene view shows specific information for a gene.',
      },
    ],
  },
  data() {
    return {
      gene: [],
      gene_fields: [
        {
          key: 'symbol',
          label: 'HGNC Symbol',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'name', label: 'Gene Name', sortable: true, class: 'text-left',
        },
        {
          key: 'entrez_id',
          label: 'Entrez',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'ensembl_gene_id',
          label: 'Ensembl',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'ucsc_id', label: 'UCSC', sortable: true, class: 'text-left',
        },
        {
          key: 'ccds_id', label: 'CCDS', sortable: true, class: 'text-left',
        },
        {
          key: 'uniprot_ids',
          label: 'UniProt',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'omim_id',
          label: 'OMIM gene',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'mgd_id', label: 'MGI', sortable: true, class: 'text-left',
        },
        {
          key: 'rgd_id', label: 'RGD', sortable: true, class: 'text-left',
        },
        {
          key: 'STRING_id',
          label: 'STRING',
          sortable: true,
          class: 'text-left',
        },
      ],
      totalRows: 0,
      loading: true,
    };
  },
  mounted() {
    this.loadGeneInfo();
  },
  methods: {
    async loadGeneInfo() {
      this.loading = true;
      const apiGeneURL = `${process.env.VUE_APP_API_URL
      }/api/gene/${
        this.$route.params.symbol
      }?input_type=hgnc`;
      const apiGeneSymbolURL = `${process.env.VUE_APP_API_URL
      }/api/gene/${
        this.$route.params.symbol
      }?input_type=symbol`;

      try {
        const response_gene = await this.axios.get(apiGeneURL);
        const response_symbol = await this.axios.get(apiGeneSymbolURL);

        if (
          response_gene.data.length === 0
          && response_symbol.data.length === 0
        ) {
          this.$router.push('/PageNotFound');
        } else if (response_gene.data.length === 0) {
          this.gene = response_symbol.data;
        } else {
          this.gene = response_gene.data;
        }
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.loading = false;
    },
    // Function to truncate a string to a specified length.
    // If the string is longer than the specified length, it adds '...' to the end.
    // imported from utils.js
    truncate(str, n) {
      // Use the utility function here
      return Utils.truncate(str, n);
    },
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
