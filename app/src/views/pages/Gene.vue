<!-- views/pages/Gene.vue -->
<template>
  <div class="container-fluid bg-gradient">
    <BSpinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <BContainer
      v-else
      fluid
    >
      <BRow
        class="justify-content-md-center py-2"
        align-v="center"
      >
        <BCol
          col
          md="12"
        >
          <!-- Gene overview card -->
          <BCard
            header-tag="header"
            class="my-3 text-start"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h3 class="mb-1 text-start font-weight-bold">
                Gene:
                <BBadge
                  pill
                  variant="success"
                >
                  {{ $route.params.symbol }}
                </BBadge>
              </h3>
            </template>

            <BTable
              :items="gene"
              :fields="gene_fields"
              stacked
              small
            >
              <template #cell(symbol)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.symbol"
                    :key="id"
                  >
                    <BCol>
                      <div class="font-italic">
                        <BLink :href="'/Genes/' + id">
                          <BBadge
                            v-b-tooltip.hover.leftbottom
                            pill
                            variant="success"
                            class="mx-2"
                            :title="id"
                          >
                            {{ id }}
                          </BBadge>
                        </BLink>
                      </div>

                      <!-- Link to HGNC -->
                      <BButton
                        v-b-tooltip.hover.leftbottom
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="
                          'https://www.genenames.org/data/gene-symbol-report/#!/symbol/' +
                            id
                        "
                        :title="id + ' in the HGNC database'"
                        target="_blank"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        <span class="font-italic"> HGNC: {{ id }} </span>
                      </BButton>

                      <!-- Link to SFARI -->
                      <BButton
                        v-b-tooltip.hover.leftbottom
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://gene.sfari.org/database/human-gene/' + id"
                        :title="id + ' in the SFARI database'"
                        target="_blank"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        <span class="font-italic"> SFARI: {{ id }} </span>
                      </BButton>

                      <!-- Link to gene2phenotype -->
                      <BButton
                        v-b-tooltip.hover.leftbottom
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://www.ebi.ac.uk/gene2phenotype/search?panel=ALL&search_term=' + id"
                        :title="id + ' in the gene2phenotype database'"
                        target="_blank"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        <span class="font-italic"> g2p: {{ id }} </span>
                      </BButton>

                      <!-- Link to PanelApp -->
                      <BButton
                        v-b-tooltip.hover.leftbottom
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://panelapp.genomicsengland.co.uk/panels/entities/' + id"
                        :title="id + ' in the PanelApp database'"
                        target="_blank"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        <span class="font-italic"> panelapp: {{ id }} </span>
                      </BButton>

                      <!-- Link to ClinGen using HGNC id -->
                      <BButton
                        v-b-tooltip.hover.leftbottom
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://search.clinicalgenome.org/kb/genes/' + data.item.hgnc_id"
                        :title="id + ' in the ClinGen database'"
                        target="_blank"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        <span class="font-italic"> ClinGen: {{ id }} </span>
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(name)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.name"
                    :key="id"
                  >
                    <BCol>
                      <span class="font-italic mx-2"> {{ id }} </span>
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(entrez_id)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.entrez_id"
                    :key="id"
                  >
                    <BCol>
                      <BButton
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://www.ncbi.nlm.nih.gov/gene/' + id"
                        target="_blank"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(ensembl_gene_id)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.ensembl_gene_id"
                    :key="id"
                  >
                    <BCol>
                      <BButton
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
                        <i class="bi bi-box-arrow-up-right" />
                        {{ id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(ucsc_id)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.ucsc_id"
                    :key="id"
                  >
                    <BCol>
                      <BButton
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
                        <i class="bi bi-box-arrow-up-right" />
                        {{ id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(ccds_id)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.ccds_id"
                    :key="id"
                  >
                    <BCol>
                      <BButton
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
                        <i class="bi bi-box-arrow-up-right" />
                        {{ id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(uniprot_ids)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.uniprot_ids"
                    :key="id"
                  >
                    <BCol>
                      <BButton
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://www.uniprot.org/uniprot/' + id"
                        target="_blank"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(omim_id)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.omim_id"
                    :key="id"
                  >
                    <BCol>
                      <BButton
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://www.omim.org/entry/' + id"
                        target="_blank"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        *{{ id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(mgd_id)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.mgd_id"
                    :key="id"
                  >
                    <BCol>
                      <BButton
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'http://www.informatics.jax.org/marker/' + id"
                        target="_blank"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(rgd_id)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.rgd_id"
                    :key="id"
                  >
                    <BCol>
                      <BButton
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
                        <i class="bi bi-box-arrow-up-right" />
                        {{ id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(STRING_id)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.STRING_id"
                    :key="id"
                  >
                    <BCol>
                      <BButton
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://string-db.org/network/' + id"
                        target="_blank"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>
            </BTable>
          </BCard>
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
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import toastMixin from '@/assets/js/mixins/toastMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';

// Import the utilities file
import Utils from '@/assets/js/utils';

export default {
  name: 'Gene',
  mixins: [toastMixin, colorAndSymbolsMixin],
  setup() {
    useHead({
      title: 'Gene',
      meta: [
        {
          name: 'description',
          content: 'This Gene view shows specific information for a gene.',
        },
      ],
    });
  },
  data() {
    return {
      gene: [],
      gene_fields: [
        {
          key: 'symbol',
          label: 'HGNC Symbol',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'name', label: 'Gene Name', sortable: true, class: 'text-start',
        },
        {
          key: 'entrez_id',
          label: 'Entrez',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'ensembl_gene_id',
          label: 'Ensembl',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'ucsc_id', label: 'UCSC', sortable: true, class: 'text-start',
        },
        {
          key: 'ccds_id', label: 'CCDS', sortable: true, class: 'text-start',
        },
        {
          key: 'uniprot_ids',
          label: 'UniProt',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'omim_id',
          label: 'OMIM gene',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'mgd_id', label: 'MGI', sortable: true, class: 'text-start',
        },
        {
          key: 'rgd_id', label: 'RGD', sortable: true, class: 'text-start',
        },
        {
          key: 'STRING_id',
          label: 'STRING',
          sortable: true,
          class: 'text-start',
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
      const apiGeneURL = `${import.meta.env.VITE_API_URL
      }/api/gene/${
        this.$route.params.symbol
      }?input_type=hgnc`;
      const apiGeneSymbolURL = `${import.meta.env.VITE_API_URL
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
