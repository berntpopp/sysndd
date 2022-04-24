<template>
  <div class="container-fluid">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">

          <!-- User Interface controls -->
          <b-card 
          header-tag="header"
          bg-variant="light"
          :header-bg-variant="header_style[curation_selected]"
          >
          <template #header>
            <b-row>
              <b-col>
                <h6 class="mb-1 text-left font-weight-bold">
                  Re-review table <b-badge variant="primary">Entities: {{totalRows}} </b-badge>
                </h6>
              </b-col>
              <b-col>
                <h6 class="mb-1 text-righ font-weight-bold">
                  <b-icon icon="person-circle" font-scale="1.0"></b-icon> <b-badge variant="dark">  {{ user.user_name[0] }} </b-badge> <b-badge variant="dark"> {{ user.user_role[0] }} </b-badge> <b-badge @click="newBatchApplication()" href="#" v-if="totalRows === 0 & (filter === null | filter === '') & !curation_selected" variant="warning" pill> New batch </b-badge>
                  <div class="custom-control custom-switch" v-if="curator_mode">
                    <input 
                      type="checkbox" 
                      button-variant="info"
                      class="custom-control-input" 
                      id="curationSwitch"
                      v-model="curation_selected"
                    >
                    <label class="custom-control-label" for="curationSwitch">Switch to curation</label>
                  </div>
                </h6>
              </b-col>
            </b-row>
          </template>
          <b-row>
            <b-col class="my-1">
              <b-form-group
                class="mb-1"
              >
                <b-input-group
                prepend="Search" 
                size="sm">
                  <b-form-input
                    id="filter-input"
                    v-model="filter"
                    type="search"
                    placeholder="any field by typing here"
                    debounce="500"
                  ></b-form-input>
                </b-input-group>
              </b-form-group>
            </b-col>

            <b-col class="my-1">
            </b-col>

            <b-col class="my-1">
            </b-col>

            <b-col class="my-1">
              <b-input-group
                prepend="Per page"
                class="mb-1"
                size="sm"
              >
                <b-form-select
                  id="per-page-select"
                  v-model="perPage"
                  :options="pageOptions"
                  size="sm"
                ></b-form-select>
              </b-input-group>

              <b-pagination
                v-model="currentPage"
                :total-rows="totalRows"
                :per-page="perPage"
                align="fill"
                size="sm"
                class="my-0"
                last-number
              ></b-pagination>
            </b-col>
          </b-row>
          </b-card>
          <!-- User Interface controls -->



          <!-- Main table element -->
          <b-table
            :items="items"
            :fields="fields"
            :current-page="currentPage"
            :per-page="perPage"
            :filter="filter"
            :filter-included-fields="filterOn"
            :sort-by.sync="sortBy"
            :sort-desc.sync="sortDesc"
            :sort-direction="sortDirection"
            stacked="md"
            head-variant="light"
            show-empty
            small
            fixed
            striped
            hover
            sort-icon-left
            :empty-text="empty_table_text[curation_selected]"
            @filtered="onFiltered"
          >

            <template #cell(actions)="row">
              <b-button 
                size="sm" 
                @click="infoReview(row.item, row.index, $event.target)" 
                class="mr-1 btn-xs"
                variant="secondary"
                v-b-tooltip.hover.left 
                title="edit review"
                >
                  <b-icon 
                  icon="pen"
                  font-scale="0.9"
                  :variant="review_style[saved(row.item.review_id)]"
                  >
                  </b-icon>
              </b-button>

              <b-button 
                size="sm" 
                @click="infoStatus(row.item, row.index, $event.target)" 
                class="mr-1 btn-xs" 
                :variant="stoplights_style[row.item.category_id]"
                v-b-tooltip.hover.top 
                title="edit status"
                >
                  <b-icon 
                  icon="stoplights"
                  font-scale="0.9"
                  :variant="status_style[saved(row.item.status_id)]"
                  >
                  </b-icon>
              </b-button>
              
              <!-- Button for review mode -->
              <b-button 
                size="sm" 
                @click="infoSubmit(row.item, row.index, $event.target)" 
                class="mr-1 btn-xs" 
                :variant="saved_style[row.item.re_review_review_saved]"
                v-b-tooltip.hover.top 
                title="submit entity review"
                v-if="!curation_selected"
              >
                <b-icon 
                icon="check2-circle"
                font-scale="0.9"
                >
                </b-icon>
              </b-button>

              <!-- Button for curation mode -->
              <b-button 
                size="sm" 
                @click="infoApprove(row.item, row.index, $event.target)" 
                class="mr-1 btn-xs" 
                variant="danger"
                v-b-tooltip.hover.right 
                title="approve entity review/status"
                v-if="curation_selected"
              >
                <b-icon 
                icon="check2-circle"
                font-scale="0.9"
                >
                </b-icon>
              </b-button>
            </template>

            <template #cell(entity_id)="data">
              <div class="overflow-hidden text-truncate">
                <b-link v-bind:href="'/Entities/' + data.item.entity_id" target="_blank">
                  <b-badge 
                  variant="primary"
                  style="cursor:pointer"
                  >
                  sysndd:{{ data.item.entity_id }}
                  </b-badge>
                </b-link>
              </div>
            </template>

            <template #cell(symbol)="data">
              <div class="font-italic overflow-hidden text-truncate">
                <b-link v-bind:href="'/Genes/' + data.item.hgnc_id" target="_blank"> 
                  <b-badge pill variant="success"
                  v-b-tooltip.hover.leftbottom 
                  v-bind:title="data.item.hgnc_id"
                  >
                  {{ data.item.symbol }}
                  </b-badge>
                </b-link>
              </div> 
            </template>

            <template #cell(disease_ontology_name)="data">
              <div class="overflow-hidden text-truncate">
                <b-link v-bind:href="'/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')" target="_blank"> 
                  <b-badge 
                  pill 
                  variant="secondary"
                  v-b-tooltip.hover.leftbottom
                  v-bind:title="data.item.disease_ontology_name + '; ' + data.item.disease_ontology_id_version"
                  >
                  {{ truncate(data.item.disease_ontology_name, 40) }}
                  </b-badge>
                </b-link>
              </div> 
            </template>

            <template #cell(hpo_mode_of_inheritance_term_name)="data">
              <div class="overflow-hidden text-truncate">
                <b-badge 
                pill 
                variant="info" 
                class="justify-content-md-center" 
                size="1.3em"
                v-b-tooltip.hover.leftbottom 
                v-bind:title="data.item.hpo_mode_of_inheritance_term_name + ' (' + data.item.hpo_mode_of_inheritance_term + ')'"
                >
                {{ inheritance_short_text[data.item.hpo_mode_of_inheritance_term_name] }}
                </b-badge>
              </div>
            </template>

            <template #cell(ndd_phenotype_word)="data">
              <div class="overflow-hidden text-truncate">
                <b-avatar 
                size="1.4em" 
                :icon="ndd_icon[data.item.ndd_phenotype_word]"
                :variant="ndd_icon_style[data.item.ndd_phenotype_word]"
                v-b-tooltip.hover.left 
                v-bind:title="ndd_icon_text[data.item.ndd_phenotype_word]"
                >
                </b-avatar>
              </div> 
            </template>

          </b-table>

        </b-col>
      </b-row>
      

      <!-- 1) Review modal -->
      <b-modal 
      :id="reviewModal.id" 
      size="xl" 
      centered 
      ok-title="Save review" 
      no-close-on-esc 
      no-close-on-backdrop 
      header-bg-variant="dark" 
      header-text-variant="light" 
      @hide="resetReviewModal" 
      @ok="handleReviewOk"
      >

        <template #modal-title>
          <h4>Entity: 
            <b-badge 
            variant="primary"
            >
            {{ reviewModal.title }}
            </b-badge>
          </h4>
          
        </template>

        <template #modal-footer="{ ok, cancel }">
          <div class="w-100">
            <p class="float-left">
              Review by: 
              <b-icon icon="person-circle" font-scale="1.0"></b-icon> <b-badge variant="dark">  {{ review[0].review_user_name }} </b-badge> <b-badge variant="dark"> {{ review[0].review_user_role }} </b-badge>
            </p>

            <!-- Emulate built in modal footer ok and cancel button actions -->
            <b-button variant="primary" class="float-right mr-2" @click="ok()">
              Save review
            </b-button>
            <b-button variant="secondary" class="float-right mr-2" @click="cancel()">
              Cancel
            </b-button>
          </div>
        </template>

      <b-container fluid v-if="loading_review_modal">
        <b-spinner label="Loading..." class="float-center"></b-spinner>
      </b-container>
      <b-container fluid v-else>

        <b-form ref="form" @submit.stop.prevent="handleSubmit">

            <!-- small entity table in review modal -->
            <b-table
                :items="entity"
                :fields="entity_fields"
                stacked="lg"
                small
            >

            <template #cell(entity_id)="data">
              <div>
                <b-link v-bind:href="'/Entities/' + data.item.entity_id" target="_blank">
                  <b-badge 
                  variant="primary"
                  style="cursor:pointer"
                  >
                  <b-icon icon="box-arrow-up-right" font-scale="0.9"></b-icon>
                  sysndd:{{ data.item.entity_id }}
                  </b-badge>
                </b-link>
              </div>
            </template>

            <template #cell(symbol)="data">
              <div class="font-italic">
                <b-link v-bind:href="'/Genes/' + data.item.hgnc_id" target="_blank"> 
                  <b-badge pill variant="success"
                  v-b-tooltip.hover.leftbottom 
                  v-bind:title="data.item.hgnc_id"
                  >
                  <b-icon icon="box-arrow-up-right" font-scale="0.9"></b-icon>
                  {{ data.item.symbol }}
                  </b-badge>
                </b-link>
              </div> 
            </template>

            <template #cell(disease_ontology_name)="data">
              <div class="overflow-hidden text-truncate">
                <b-link v-bind:href="'/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')" target="_blank"> 
                  <b-badge 
                  pill 
                  variant="secondary"
                  v-b-tooltip.hover.leftbottom
                  v-bind:title="data.item.disease_ontology_name + '; ' + data.item.disease_ontology_id_version"
                  >
                  <b-icon icon="box-arrow-up-right" font-scale="0.9"></b-icon>
                  {{ truncate(data.item.disease_ontology_name, 40) }}
                  </b-badge>
                </b-link>
              </div> 
            </template>

            <template #cell(hpo_mode_of_inheritance_term_name)="data">
              <div>
                <b-badge 
                pill 
                variant="info" 
                class="justify-content-md-center" 
                size="1.3em"
                v-b-tooltip.hover.leftbottom 
                v-bind:title="data.item.hpo_mode_of_inheritance_term_name + ' (' + data.item.hpo_mode_of_inheritance_term + ')'"
                >
                {{ inheritance_short_text[data.item.hpo_mode_of_inheritance_term_name] }}
                </b-badge>
              </div>
            </template>

            <template #cell(ndd_phenotype_word)="data">
              <div>
                <b-avatar 
                size="1.4em" 
                :icon="ndd_icon[data.item.ndd_phenotype_word]"
                :variant="ndd_icon_style[data.item.ndd_phenotype_word]"
                v-b-tooltip.hover.left 
                v-bind:title="ndd_icon_text[data.item.ndd_phenotype_word]"
                >
                </b-avatar>
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
            
            </b-table>
            <!-- small entity table in review modal -->
            
              <label class="mr-sm-2 font-weight-bold" for="textarea-synopsis">Synopsis</label>
                <b-badge pill id="popover-badge-help-synopsis" href="#" variant="info">
                  <b-icon icon="question-circle-fill"></b-icon>
                </b-badge>

                <b-popover target="popover-badge-help-synopsis" variant="info" triggers="focus">
                <template #title>Synopsis instructions</template>
                    Short summary for this disease entity. 
                    Please include information on: <br>
                    <strong>a)</strong> approximate number of patients described in literature, <br> 
                    <strong>b)</strong> nature of reported variants, <br>
                    <strong>c)</strong> severity of intellectual disability, <br>
                    <strong>d)</strong> further phenotypic aspects (if possible with frequencies), <br> 
                    <strong>e)</strong> any valuable further information (e.g. genotype-phenotype correlations).<br>
                </b-popover>

                <b-form-textarea
                  id="textarea-synopsis"
                  rows="3"
                  size="sm" 
                  v-model="synopsis_review"
                >
                </b-form-textarea>

              <label class="mr-sm-2 font-weight-bold" for="phenotype-select">Phenotypes</label>
                <b-badge pill id="popover-badge-help-phenotypes" href="#" variant="info">
                  <b-icon icon="question-circle-fill"></b-icon>
                </b-badge>

                <b-popover target="popover-badge-help-phenotypes" variant="info" triggers="focus">
                <template #title>Phenotypes instructions</template>
                  Add or remove associated phenotypes. 
                  Only phenotypes that occur in 20% or more of affected individuals should be included. 
                  Please also include information on severity of ID.
                </b-popover>
                
                <treeselect 
                  id="phenotype_select"
                  v-model="phenotypes_review" 
                  :multiple="true" 
                  :options="phenotypes_options"
                  :normalizer="normalizer"
                />

              <label class="mr-sm-2 font-weight-bold" for="publications-select">Publications</label>
                <b-badge pill id="popover-badge-help-publications" href="#" variant="info">
                  <b-icon icon="question-circle-fill"></b-icon>
                </b-badge>

                <b-popover target="popover-badge-help-publications" variant="info" triggers="focus">
                <template #title>Publications instructions</template>
                  No complete catalogue of entity-related literature required. <br>
                  If information in the clinical synopsis is not only based on OMIM entries,
                  please include PMID of the article(s) used as a source for the clinical synopsis. <br>
                  - Input is only valid when starting with <strong>"PMID:"</strong> followed by a number
                </b-popover>

                <!-- publications tag form with links out -->
                <b-form-tags 
                input-id="literature-select"
                v-model="literature_review" 
                no-outer-focus 
                class="my-0"
                separator=" ,;"
                :tag-validator="tagValidatorPMID"
                remove-on-delete
                >
                  <template v-slot="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
                    <b-input-group class="my-0">
                      <b-form-input
                        v-bind="inputAttrs"
                        v-on="inputHandlers"
                        placeholder="Enter PMIDs separated by space, comma or semicolon"
                        class="form-control"
                        size="sm"
                      ></b-form-input>
                      <b-input-group-append>
                        <b-button @click="addTag()" 
                        variant="secondary"
                        size="sm"
                        >
                        Add
                        </b-button>
                      </b-input-group-append>
                    </b-input-group>

                    <div class="d-inline-block">
                      <h6>
                      <b-form-tag
                      v-for="tag in tags"
                      @remove="removeTag(tag)"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      >
                        <b-link 
                        v-bind:href="'https://pubmed.ncbi.nlm.nih.gov/' + tag.replace('PMID:', '')" 
                        target="_blank" 
                        class="text-light"
                        >
                        <b-icon icon="box-arrow-up-right" font-scale="0.9"></b-icon>
                          {{ tag }}
                        </b-link>
                      </b-form-tag>
                      </h6>
                    </div>

                  </template>
                </b-form-tags>


              <label class="mr-sm-2 font-weight-bold" for="genereviews-select">GeneReviews</label>
                <b-badge pill id="popover-badge-help-genereviews" href="#" variant="info">
                  <b-icon icon="question-circle-fill"></b-icon>
                </b-badge>

                <b-popover target="popover-badge-help-genereviews" variant="info" triggers="focus">
                <template #title>GeneReviews instructions</template>
                  Please add PMID for GeneReview article if available for this entity. <br>
                  - Input is only valid when starting with <strong>"PMID:"</strong> followed by a number
                </b-popover>


                <!-- genereviews tag form with links out -->
                <b-form-tags 
                input-id="genereviews-select"
                v-model="genereviews_review" 
                no-outer-focus 
                class="my-0"
                separator=" ,;"
                :tag-validator="tagValidatorPMID"
                remove-on-delete
                >
                  <template v-slot="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
                    <b-input-group class="my-0">
                      <b-form-input
                        v-bind="inputAttrs"
                        v-on="inputHandlers"
                        placeholder="Enter PMIDs separated by space, comma or semicolon"
                        class="form-control"
                        size="sm"
                      ></b-form-input>
                      <b-input-group-append>
                        <b-button @click="addTag()" 
                        variant="secondary"
                        size="sm"
                        >
                        Add
                        </b-button>
                      </b-input-group-append>
                    </b-input-group>

                    <div class="d-inline-block">
                      <h6>
                      <b-form-tag
                      v-for="tag in tags"
                      @remove="removeTag(tag)"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      >
                        <b-link 
                        v-bind:href="'https://pubmed.ncbi.nlm.nih.gov/' + tag.replace('PMID:', '')" 
                        target="_blank" 
                        class="text-light"
                        >
                        <b-icon icon="box-arrow-up-right" font-scale="0.9"></b-icon>
                          {{ tag }}
                        </b-link>
                      </b-form-tag>
                      </h6>
                    </div>

                  </template>
                </b-form-tags>

          <label class="mr-sm-2 font-weight-bold" for="textarea-review">Comment</label>
          <b-form-textarea
            id="textarea-review"
            rows="2"
            size="sm" 
            v-model="review_comment"
            placeholder="Additional comments to this entity relevant for the curator."
          >
          </b-form-textarea>
        </b-form>
      </b-container>
      </b-modal>
      <!-- 1) Review modal -->


      <!-- 2) Status modal -->
      <b-modal 
      :id="statusModal.id" 
      size="lg" 
      centered 
      ok-title="Save status" 
      no-close-on-esc 
      no-close-on-backdrop 
      header-bg-variant="dark" 
      header-text-variant="light" 
      @hide="resetStatusModal" 
      @ok="handleStatusOk"
      >
        <template #modal-title>
          <h4>Entity: 
            <b-badge variant="primary">
              {{ statusModal.title }}
            </b-badge>
          </h4>
        </template>

        <template #modal-footer="{ ok, cancel }">
          <div class="w-100">
            <p class="float-left">
              Status by: 
              <b-icon icon="person-circle" font-scale="1.0"></b-icon> <b-badge variant="dark">  {{ status[0].status_user_name }} </b-badge> <b-badge variant="dark"> {{ status[0].status_user_role }} </b-badge>
            </p>

            <!-- Emulate built in modal footer ok and cancel button actions -->
            <b-button variant="primary" class="float-right mr-2" @click="ok()">
              Save status
            </b-button>
            <b-button variant="secondary" class="float-right mr-2" @click="cancel()">
              Cancel
            </b-button>
          </div>
        </template>

        <b-form ref="form" @submit.stop.prevent="handleSubmit">
          <label class="mr-sm-2 font-weight-bold" for="status-select">Status</label>
          <b-icon 
            icon="stoplights-fill"
            :variant="stoplights_style[status_selected]"
          >
          </b-icon>
          <b-form-select 
            id="status-select" 
            class="form-control"
            :options="status_options"
            v-model="status_selected"
          >
          </b-form-select>

          <div class="custom-control custom-switch">
          <input 
            type="checkbox" 
            button-variant="info"
            class="custom-control-input" 
            id="removeSwitch"
            v-model="removal_selected"
          >
          <label class="custom-control-label" for="removeSwitch">Suggest removal</label>
          </div>

          <label class="mr-sm-2 font-weight-bold" for="status-textarea-comment">Comment</label>
          <b-form-textarea
            id="status-textarea-comment"
            rows="2"
            size="sm" 
            v-model="status_comment"
            placeholder="Why should this entities status be changed."
          >
          </b-form-textarea>
        </b-form>
      </b-modal>
      <!-- 2) Status modal -->


      <!-- 3) Submit modal -->
      <b-modal 
      :id="submitModal.id" 
      size="sm" 
      centered 
      ok-title="Submit review" 
      no-close-on-esc 
      no-close-on-backdrop 
      header-bg-variant="dark" 
      header-text-variant="light" 
      @ok="handleSubmitOk"
      >
        <template #modal-title>
          <h4>Entity: 
            <b-badge variant="primary">
              {{ submitModal.title }}
            </b-badge>
          </h4>
        </template>

        You have finished the re-review of this entity and <span class="font-weight-bold">want to submit it</span>?

      </b-modal>
      <!-- 3) Submit modal -->


      <!-- 4) Approve modal -->
      <b-modal 
      :id="approveModal.id" 
      size="sm" 
      centered 
      ok-title="Approve" 
      no-close-on-esc 
      no-close-on-backdrop 
      header-bg-variant="dark" 
      header-text-variant="light" 
      @ok="handleApproveOk"
      >
        <template #modal-title>
          <h4>Entity: 
            <b-badge variant="primary">
              {{ approveModal.title }}
            </b-badge>
          </h4>
        </template>
        What should be approved ?

          <div class="custom-control custom-switch">
          <input 
            type="checkbox" 
            button-variant="info"
            class="custom-control-input" 
            id="approveReviewSwitch"
            v-model="review_approved"
          >
          <label class="custom-control-label" for="approveReviewSwitch">Review</label>
          </div>

          <div class="custom-control custom-switch">
          <input 
            type="checkbox" 
            button-variant="info"
            class="custom-control-input" 
            id="approveStatusSwitch"
            v-model="status_approved"
          >
          <label class="custom-control-label" for="approveStatusSwitch">Status</label>
          </div>

          <div>
            <b-button 
            size="sm" 
            variant="warning"
            @click="handleUnsetSubmission()" 
            >
              <b-icon icon="unlock" font-scale="1.0"></b-icon> Unsubmit
            </b-button>
          </div>
      </b-modal>
      <!-- 4) Approve modal -->

    </b-container>

  </div>
</template>


<script>
  // import the Treeselect component
  import Treeselect from '@riophae/vue-treeselect'
  // import the Treeselect styles
  import '@riophae/vue-treeselect/dist/vue-treeselect.css'

export default {
  // register the Treeselect component
  components: { Treeselect },
  name: 'Review',
  data() {
        return {
          stoplights_style: {1: "success", 2: "primary", 3: "warning", 4: "danger", "Definitive": "success", "Moderate": "primary", "Limited": "warning", "Refuted": "danger"},
          saved_style: {0: "secondary", 1: "info"},
          review_style: {0: "light", 1: "dark"},
          status_style: {0: "light", 1: "dark"},
          header_style: {false: "light", true: "danger"},
          ndd_icon: {"No": "x", "Yes": "check"},
          ndd_icon_style: {"No": "warning", "Yes": "success"},
          ndd_icon_text: {"No": "not associated with NDDs", "Yes": "associated with NDDs"},
          inheritance_short_text: {"Autosomal dominant inheritance": "AD", "Autosomal recessive inheritance": "AR", "X-linked inheritance": "X", "X-linked recessive inheritance": "XR", "X-linked dominant inheritance": "XD", "Mitochondrial inheritance": "M", "Somatic mutation": "S", "Semidominant mode of inheritance": "sD"},
          empty_table_text: {false: "Apply for a new batch of entities.", true: "Nothing to review."},
          items: [],
          fields: [
            { key: 'entity_id', label: 'Entity', sortable: true, sortDirection: 'desc', class: 'text-left' },
            { key: 'symbol', label: 'Gene', sortable: true, class: 'text-left' },
            {
              key: 'disease_ontology_name',
              label: 'Disease',
              sortable: true,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            {
              key: 'hpo_mode_of_inheritance_term_name',
              label: 'Inheritance',
              sortable: true,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            { key: 'ndd_phenotype_word', label: 'NDD', sortable: true, class: 'text-left' },
            { key: 'actions', label: 'Actions' }
          ],
          totalRows: 1,
          currentPage: 1,
          perPage: 10,
          pageOptions: [10, 25, 50, { value: 100, text: "Show a lot" }],
          sortBy: '',
          sortDesc: false,
          sortDirection: 'asc',
          filter: null,
          filterOn: [],
          reviewModal: {
            id: 'review-modal',
            title: '',
            content: []
          },
          statusModal: {
            id: 'status-modal',
            title: '',
            content: []
          },
          submitModal: {
            id: 'submit-modal',
            title: '',
            content: []
          },
          approveModal: {
            id: 'approve-modal',
            title: '',
            content: []
          },
          entity: [],
          entity_fields: [
            { key: 'entity_id', label: 'Entity', sortable: true, sortDirection: 'desc', class: 'text-left' },
            { key: 'symbol', label: 'Gene', sortable: false, class: 'text-left' },
            {
              key: 'disease_ontology_name',
              label: 'Disease',
              sortable: false,
              class: 'text-left'
            },
            {
              key: 'hpo_mode_of_inheritance_term_name',
              label: 'Inheritance',
              sortable: false,
              class: 'text-left'
            },
            { 
              key: 'ndd_phenotype_word', 
              label: 'NDD', 
              sortable: false, 
              class: 'text-left' 
            },
            { 
              key: 'category', 
              label: 'Category', 
              sortable: false, 
              class: 'text-left' 
            }
          ],
          review: [{synopsis: ''}],
          review_fields: [
            { key: 'synopsis', label: 'Clinical Synopsis', class: 'text-left' },
          ],
          review_number: 0,
          synopsis_review: '',
          review_comment: '',
          status_comment: '',
          publications: [],
          literature_review: [],
          genereviews_review: [],
          publication_options: [],
          phenotypes_review: [],
          phenotypes_options: [],
          status: [{status_user_name: ''}],
          status_options: [],
          status_selected: 0,
          removal_selected: 0,
          curation_selected: false,
          review_approved: false,
          status_approved: false,
          curator_mode: 0,
          loading: true,
          loading_review_modal: true,
          user: {
            "user_id": [],
            "user_name": [],
            "email": [],
            "user_role": [],
            "user_created": [],
            "abbreviation": [],
            "orcid": [],
            "exp": []
          },
          state: false
        }
      },
      computed: {
        sortOptions() {
          // Create an options list from our fields
          return this.fields
            .filter(f => f.sortable)
            .map(f => {
              return { text: f.label, value: f.key }
            })
        }
      },
      watch: { // used to reload table when switching curator mode
      curation_selected: function(newVal, oldVal) { // watch it

          this.reloadReReviewData();
        }
      },
      mounted() {
        if (localStorage.user) {
        this.user = JSON.parse(localStorage.user);
        this.curator_mode = (this.user.user_role[0] === 'Admin' | this.user.user_role[0] === 'Curator');
        }
        this.loadReReviewData();
        this.loadPhenotypesList();
        this.loadStatusList();
      },
      methods: {
        onFiltered(filteredItems) {
          // Trigger pagination to update the number of buttons/pages due to filtering
          this.totalRows = filteredItems.length;
          this.currentPage = 1;
        },
        resetReviewModal() {
          this.reviewModal.title = '';
          this.reviewModal.content = [];
          this.entity = [];
          this.entity_review = [];
          this.synopsis_review = '';
          this.phenotypes_review = [];
          this.literature_review = [];
          this.genereviews_review = [];
          this.review_comment = '';
        },
        resetStatusModal() {
          this.status = [{status_user_name: ''}];
          this.status_selected = 0;
          this.removal_selected = 0;
          this.status_comment = '';
        },
        resetApproveModal() {
          this.status_approved = false;
          this.review_approved = false;
          this.status_comment = '';
        },
        infoReview(item, index, button) {
          this.reviewModal.title = `sysndd:${item.entity_id}`;
          this.entity = [];
          this.entity.push(item);
          
          this.loadReviewInfo(item.review_id);
          this.$root.$emit('bv::show::modal', this.reviewModal.id, button);
        },
        infoStatus(item, index, button) {
          this.statusModal.title = `sysndd:${item.entity_id}`;
          this.entity = [];
          this.entity.push(item);
          this.loadStatusInfo(item.status_id);
          this.$root.$emit('bv::show::modal', this.statusModal.id, button);
        },
        infoSubmit(item, index, button) {
          this.submitModal.title = `sysndd:${item.entity_id}`;
          this.entity = [];
          this.entity.push(item);
          this.$root.$emit('bv::show::modal', this.submitModal.id, button);
        },
        infoApprove(item, index, button) {
          this.approveModal.title = `sysndd:${item.entity_id}`;
          this.entity = [];
          this.entity.push(item);
          this.$root.$emit('bv::show::modal', this.approveModal.id, button);
        },
        async loadReReviewData() {
          this.loading = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/alb/re_review_table';
          try {
            let response = await this.axios.get(apiUrl, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });

            this.items = response.data;
            this.totalRows = response.data.length;
          } catch (e) {
            console.error(e);
          }
          this.loading = false;
        },
        async reloadReReviewData() {
          this.loading = true;

          this.items = [];
          let apiUrl = process.env.VUE_APP_API_URL + '/alb/re_review_table?curate=' + this.curation_selected;
          try {
            let response = await this.axios.get(apiUrl, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });

            this.items = response.data;
            this.totalRows = response.data.length;
          } catch (e) {
            console.error(e);
          }
          this.loading = false;
        },
        async loadReviewInfo(review_id) {
          this.loading_review_modal = true;

          // define API query URLs
          let apiReviewURL = process.env.VUE_APP_API_URL + '/alb/review/' + review_id;
          let apiPublicationsURL = process.env.VUE_APP_API_URL + '/alb/review/' + review_id + '/publications';
          let apiPhenotypesURL = process.env.VUE_APP_API_URL + '/alb/review/' + review_id + '/phenotypes';

          try {
            // get API responses
            let response_review = await this.axios.get(apiReviewURL);
            let response_publications = await this.axios.get(apiPublicationsURL);
            let response_phenotypes = await this.axios.get(apiPhenotypesURL);

            // assign response data to global variables
            this.review = response_review.data;
            this.phenotypes = response_phenotypes.data;

            this.synopsis_review = this.review[this.review_number].synopsis;
            if (this.review[this.review_number].comment !== null) {
              this.review_comment = this.review[this.review_number].comment;
            } else {
              this.review_comment = '';
            }
            
            Object.entries(this.phenotypes).forEach(([key, value]) => this.phenotypes_review.push(value.phenotype_id));

            // filter the publications data into groups and assign to global variables
            let literature_filter = response_publications.data.filter(li => li.publication_type === "additional_references");
            let genereviews_filter = response_publications.data.filter(gr => gr.publication_type === "gene_review");
            Object.entries(literature_filter).forEach(([key, value]) => this.literature_review.push(value.publication_id));
            Object.entries(genereviews_filter).forEach(([key, value]) => this.genereviews_review.push(value.publication_id));

          this.loading_review_modal = false;

            } catch (e) {
            console.error(e);
            }
        },
        async loadStatusInfo(status_id) {
          // define API query URLs
          let apiStatusURL = process.env.VUE_APP_API_URL + '/alb/status/' + status_id;

          try {
            // get API responses
            let response_status = await this.axios.get(apiStatusURL);

            // assign response data to global variables
            this.status = response_status.data;

            this.status_selected = response_status.data[0].category_id;
            if (response_status.data[0].comment !== null) {
              this.status_comment = response_status.data[0].comment;
            } else {
              this.status_comment = '';
            }
            this.removal_selected = response_status.data[0].problematic;

            } catch (e) {
            console.error(e);
            }
        },
        async loadPhenotypesList() {
          let apiUrl = process.env.VUE_APP_API_URL + '/alb/list/phenotype';
          try {
            let response = await this.axios.get(apiUrl);
            this.phenotypes_options = response.data;
          } catch (e) {
            console.error(e);
          }
        },
        normalizer(node) {
          return {
            id: node.phenotype_id,
            label: node.HPO_term,
          }
        },
        async loadStatusList() {
          let apiUrl = process.env.VUE_APP_API_URL + '/alb/status_list';
          try {
            let response = await this.axios.get(apiUrl);
            //Object.entries(response.data).forEach(([key, value]) => this.status_options.push(value.category));
            this.status_options = response.data.map(item => {
              return { value: item.category_id, text: item.category };
            });

          } catch (e) {
            console.error(e);
          }
        },
        async submitReview(submission) {

          let apiUrl = process.env.VUE_APP_API_URL + '/alb/re_review/review?review_json=';
          
          if (this.entity[0].re_review_review_saved === 1) {
            try {
              let submission_json = JSON.stringify(submission);

              let response = await this.axios.put(apiUrl + submission_json, {}, {
                headers: {
                  'Authorization': 'Bearer ' + localStorage.getItem('token')
                }
              });
            } catch (e) {
              console.error(e);
            }
          } else {
            try {
              let submission_json = JSON.stringify(submission);

              let response = await this.axios.post(apiUrl + submission_json, {}, {
                headers: {
                  'Authorization': 'Bearer ' + localStorage.getItem('token')
                }
              });
            } catch (e) {
              console.error(e);
            }
          }
        },
        handleReviewOk(bvModalEvt) {

          const review_submission = {};
          const phenotypes_submission = this.phenotypes_review;

          // TO DO: need to change this to incorporate real modifiers selection
          const modifiers_submission = [];
          Object.entries(this.phenotypes_review).forEach(([value]) => {
            modifiers_submission.push(1);
            }
          );

          review_submission.re_review_entity_id = this.entity[0].re_review_entity_id;
          review_submission.entity_id = this.entity[0].entity_id;
          review_submission.synopsis = encodeURIComponent(this.synopsis_review);
          review_submission.literature = {};
          review_submission.literature.additional_references = this.literature_review;
          review_submission.literature.gene_review = this.genereviews_review;
          review_submission.phenotypes = {};
          review_submission.phenotypes.phenotype_id = phenotypes_submission;
          review_submission.phenotypes.modifier_id = modifiers_submission;
          review_submission.comment = encodeURIComponent(this.review_comment);

          this.submitReview(review_submission);
          this.resetReviewModal();
          this.reloadReReviewData();
        },
        async submitStatus(status) {
          let apiUrl = process.env.VUE_APP_API_URL + '/alb/re_review/status?status_json=';
          
          if (this.entity[0].re_review_status_saved === 1) {
            try {
              let status_json = JSON.stringify(status);
              let response = await this.axios.put(apiUrl + status_json, {}, {
                headers: {
                  'Authorization': 'Bearer ' + localStorage.getItem('token')
                }
              });
            } catch (e) {
              console.error(e);
            }
          } else {
            try {
              let status_json = JSON.stringify(status);

              let response = await this.axios.post(apiUrl + status_json, {}, {
                headers: {
                  'Authorization': 'Bearer ' + localStorage.getItem('token')
                }
              });
            } catch (e) {
              console.error(e);
            }
          }
        },
        handleStatusOk(bvModalEvt) {
          let status_submission = {};

          status_submission.re_review_entity_id = this.entity[0].re_review_entity_id;
          status_submission.entity_id = this.entity[0].entity_id;
          status_submission.category_id = this.status_selected;
          status_submission.comment = this.status_comment;
          status_submission.problematic = this.removal_selected;

          this.submitStatus(status_submission);
          this.resetStatusModal();
          this.reloadReReviewData();

        },
        async handleSubmitOk(bvModalEvt) {

          let re_review_submission = {};

          re_review_submission.re_review_entity_id = this.entity[0].re_review_entity_id;
          re_review_submission.re_review_submitted = 1;

          let apiUrl = process.env.VUE_APP_API_URL + '/alb/re_review/submit?submit_json=';
          try {
            let submit_json = JSON.stringify(re_review_submission);
            let response = await this.axios.put(apiUrl + submit_json, {}, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
          } catch (e) {
            console.error(e);
          }

        this.reloadReReviewData();
        
        },
        async handleApproveOk(bvModalEvt) {

          let apiUrl = process.env.VUE_APP_API_URL + '/alb/re_review/approve/' + this.entity[0].re_review_entity_id + '?status_ok=' + this.status_approved + '&review_ok=' + this.review_approved;

          try {
            let response = await this.axios.put(apiUrl, {}, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
          } catch (e) {
            console.error(e);
          }

        this.resetApproveModal();
        this.reloadReReviewData();

        },
        async handleUnsetSubmission(bvModalEvt) {

          let apiUrl = process.env.VUE_APP_API_URL + '/alb/re_review/unsubmit/' + this.entity[0].re_review_entity_id;

          try {
            let response = await this.axios.put(apiUrl, {}, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
          } catch (e) {
            console.error(e);
          }

        this.resetApproveModal();
        this.reloadReReviewData();

        },
        async newBatchApplication() {

          let apiUrl = process.env.VUE_APP_API_URL + '/alb/re_review/batch/apply';

          try {
            let response = await this.axios.get(apiUrl, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
            this.makeToast('Application send.', 'Success', 'success');
          } catch (e) {
            console.error(e);
          }
        },
        addTag(newTag) {
            const tag = {
              phenotype_id: newTag
            }
            this.options.push(tag);
            this.value.push(tag);
        },
        tagValidatorPMID(tag) {
          // Individual PMID tag validator function
          return !isNaN(Number(tag.replace('PMID:', ''))) && tag.includes('PMID:') && tag.replace('PMID:', '').length > 4 && tag.replace('PMID:', '').length < 9;
        },
        saved(any_id) {
          // check if id is new
          let number_return = 0;
          if (any_id <= 3490) {
            number_return = 0;
          } else 
          {
            number_return = 1;
          }
          return number_return;
        },
        makeToast(event, title = null, variant = null) {
            this.$bvToast.toast('' + event, {
              title: title,
              toaster: 'b-toaster-top-right',
              variant: variant,
              solid: true
            })
        },
        truncate(str, n) {
          return (str.length > n) ? str.substr(0, n-1) + '...' : str;
        }
      }
  }
</script>


<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
  .badge-container .badge {
  width: 170px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space:nowrap;
  }
</style>