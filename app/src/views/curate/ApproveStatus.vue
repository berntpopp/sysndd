<template>
  <div class="container-fluid">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">


          <!-- User Interface controls -->
          <b-card 
          header-tag="header"
          bg-variant="light"
          >
            <template #header>
              <h6 class="mb-1 text-left font-weight-bold">
                Approve new status
              </h6>
            </template>
          </b-card>
          <!-- User Interface controls -->

              <b-spinner label="Loading..." v-if="loadingStatusApprove" class="float-center m-5"></b-spinner>
              <b-table
                :items="items_StatusTable"
                :fields="fields_StatusTable"
                stacked="md"
                head-variant="light"
                show-empty
                small
                fixed
                striped
                hover
                sort-icon-left
                v-else
              >

              <template #cell(entity_id)="data">
                <div>
                  <b-link v-bind:href="'/Entities/' + data.item.entity_id">
                    <b-badge 
                    variant="primary"
                    style="cursor:pointer"
                    >
                    sysndd:{{ data.item.entity_id }}
                    </b-badge>
                  </b-link>
                </div>
              </template>

              <template #cell(category)="data">
                <div>
                  <b-avatar
                  size="1.4em"
                  icon="stoplights"
                  :variant="stoplights_style[data.item.category]"
                  v-b-tooltip.hover.left 
                  v-bind:title="data.item.category"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(problematic)="data">
                <div>
                  <b-avatar
                  size="1.4em"
                  :icon="problematic_symbol[data.item.problematic]"
                  :variant="problematic_style[data.item.problematic]"
                  v-b-tooltip.hover.left 
                  v-bind:title="problematic_text[data.item.problematic]"
                  >
                  </b-avatar>
                </div> 
              </template>

              <template #cell(comment)="data">
                <div>
                  <b-form-textarea
                    plaintext 
                    size="sm"
                    rows="1"
                    :value="data.item.comment"
                  >
                  </b-form-textarea>
                </div> 
              </template>

              <template #cell(actions)="row">
                <b-button 
                size="sm"
                class="mr-1 btn-xs"
                variant="outline-primary" 
                @click="row.toggleDetails"
                >
                  <b-icon 
                  :icon="row.detailsShowing ? 'eye-slash' : 'eye'"
                  font-scale="0.9"
                  >
                  </b-icon>
                </b-button>

                <b-button 
                  size="sm" 
                  class="mr-1 btn-xs"
                  variant="secondary"
                  v-b-tooltip.hover.left 
                  title="Edit status"
                  >
                    <b-icon 
                    icon="pen"
                    font-scale="0.9"
                    >
                    </b-icon>
                </b-button>

                <b-button 
                  size="sm" 
                  class="mr-1 btn-xs" 
                  variant="danger"
                  v-b-tooltip.hover.right 
                  title="Approve status"
                >
                  <b-icon 
                  icon="check2-circle"
                  font-scale="0.9"
                  >
                  </b-icon>
                </b-button>

              </template>

              <template #row-details="row">
                <b-card>
                  <b-table
                    :items="[row.item]"
                    :fields="fields_details_StatusTable"
                    stacked 
                    small
                  >
                  </b-table>
                </b-card>
              </template>

              </b-table>

        </b-col>
      </b-row>

    </b-container>
  </div>
</template>


<script>

export default {
  name: 'ApproveStatus',
    data() {
      return {
        stoplights_style: {"Definitive": "success", "Moderate": "primary", "Limited": "warning", "Refuted": "danger"},
        problematic_style: {"0": "success", "1": "danger"},
        problematic_symbol: {"0": "check-square", "1": "question-square"},
        problematic_text: {"0": "No problems", "1": "Entitiy status marked problematic"},
        items_StatusTable: [],
        fields_StatusTable: [
            { key: 'entity_id', label: 'Entity', sortable: true, filterable: true, sortDirection: 'desc', class: 'text-left' },
            { key: 'category', label: 'Category', sortable: true, filterable: true, class: 'text-left' },
            { key: 'comment', label: 'Comment', sortable: true, filterable: true, class: 'text-left' },
            { key: 'problematic', label: 'Problematic', sortable: true, filterable: true, class: 'text-left' },
            { key: 'actions', label: 'Actions' }
        ],
        fields_details_StatusTable: [
            { key: 'status_id', label: 'Status ID', sortable: true, filterable: true, sortDirection: 'desc', class: 'text-left' },
            { key: 'status_date', label: 'Status date', sortable: true, filterable: true, class: 'text-left' },
            { key: 'status_user_id', label: 'Status user ID', sortable: true, filterable: true, class: 'text-left' },
            { key: 'is_active', label: 'Active', sortable: true, filterable: true, class: 'text-left' },
            { key: 'comment', label: 'Comment', sortable: true, filterable: true, class: 'text-left' }
        ],
        loadingStatusApprove: true,
      };
    },
    mounted() {
      this.loadStatusTableData();
    },
    methods: {
        async loadStatusTableData() {
          this.loadingStatusApprove = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/status';
          try {
            let response = await this.axios.get(apiUrl, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
            this.items_StatusTable = response.data;
            this.totalRows_StatusTable = response.data.length;
          } catch (e) {
            console.error(e);
          }
          this.loadingStatusApprove = false;
        },
    }
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