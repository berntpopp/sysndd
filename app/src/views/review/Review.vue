<!-- views/review/Review.vue -->
<template>
  <div class="container-fluid">
    <b-spinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <b-container
      v-else
      fluid
    >
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="12"
        >
          <!-- User Interface controls -->
          <b-card
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
            :header-bg-variant="header_style[curation_selected]"
          >
            <template #header>
              <b-row>
                <b-col>
                  <h6 class="mb-1 text-left font-weight-bold">
                    Re-review table
                    <b-badge variant="primary">
                      Entities: {{ totalRows }}
                    </b-badge>
                  </h6>
                </b-col>
                <b-col>
                  <h6 class="mb-1 text-right font-weight-bold">
                    <b-icon
                      :icon="user_icon[user.user_role[0]]"
                      :variant="user_style[user.user_role[0]]"
                      font-scale="1.0"
                    />
                    <b-badge
                      :variant="user_style[user.user_role[0]]"
                      class="ml-1"
                    >
                      {{ user.user_name[0] }}
                    </b-badge>
                    <b-badge
                      :variant="user_style[user.user_role[0]]"
                      class="ml-1"
                    >
                      {{ user.user_role[0] }}
                    </b-badge>
                    <b-badge
                      v-if="
                        (totalRows === 0) &
                          ((filter === null) | (filter === '')) &
                          !curation_selected
                      "
                      href="#"
                      variant="warning"
                      pill
                      @click="newBatchApplication()"
                    >
                      New batch
                    </b-badge>
                    <div
                      v-if="curator_mode"
                      class="custom-control custom-switch"
                    >
                      <input
                        id="curationSwitch"
                        v-model="curation_selected"
                        type="checkbox"
                        button-variant="info"
                        class="custom-control-input"
                      >
                      <label
                        class="custom-control-label"
                        for="curationSwitch"
                      >Switch to curation</label>
                    </div>
                  </h6>
                </b-col>
              </b-row>
            </template>

            <b-row>
              <b-col class="my-1">
                <b-form-group class="mb-1">
                  <b-input-group
                    prepend="Search"
                    size="sm"
                  >
                    <b-form-input
                      id="filter-input"
                      v-model="filter"
                      type="search"
                      placeholder="any field by typing here"
                      debounce="500"
                    />
                  </b-input-group>
                </b-form-group>
              </b-col>

              <b-col class="my-1" />

              <b-col class="my-1" />

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
                  />
                </b-input-group>

                <b-pagination
                  v-model="currentPage"
                  :total-rows="totalRows"
                  :per-page="perPage"
                  align="fill"
                  size="sm"
                  class="my-0"
                  last-number
                />
              </b-col>
            </b-row>
            <!-- User Interface controls -->

            <!-- Main table element -->
            <b-table
              :items="items"
              :fields="fields"
              :busy="isBusy"
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
                  v-b-tooltip.hover.left
                  size="sm"
                  class="mr-1 btn-xs"
                  variant="secondary"
                  title="edit review"
                  @click="infoReview(row.item, row.index, $event.target)"
                >
                  <b-icon
                    icon="pen"
                    font-scale="0.9"
                    :variant="review_style[saved(row.item.review_id)]"
                  />
                </b-button>

                <b-button
                  v-b-tooltip.hover.top
                  size="sm"
                  class="mr-1 btn-xs"
                  :variant="stoplights_style[row.item.category_id]"
                  title="edit status"
                  @click="infoStatus(row.item, row.index, $event.target)"
                >
                  <b-icon
                    icon="stoplights"
                    font-scale="0.9"
                    :variant="status_style[saved(row.item.status_id)]"
                  />
                </b-button>

                <!-- Button for review mode -->
                <b-button
                  v-if="!curation_selected"
                  v-b-tooltip.hover.top
                  size="sm"
                  class="mr-1 btn-xs"
                  :variant="saved_style[row.item.re_review_review_saved]"
                  title="submit entity review"
                  @click="infoSubmit(row.item, row.index, $event.target)"
                >
                  <b-icon
                    icon="check2-circle"
                    font-scale="0.9"
                  />
                </b-button>

                <!-- Button for curation mode -->
                <b-button
                  v-if="curation_selected"
                  v-b-tooltip.hover.right
                  size="sm"
                  class="mr-1 btn-xs"
                  variant="danger"
                  title="approve entity review/status"
                  @click="infoApprove(row.item, row.index, $event.target)"
                >
                  <b-icon
                    icon="check2-circle"
                    font-scale="0.9"
                  />
                </b-button>
              </template>

              <template #cell(entity_id)="data">
                <div class="overflow-hidden text-truncate">
                  <b-link
                    :href="'/Entities/' + data.item.entity_id"
                    target="_blank"
                  >
                    <b-badge
                      variant="primary"
                      style="cursor: pointer"
                    >
                      sysndd:{{ data.item.entity_id }}
                    </b-badge>
                  </b-link>
                </div>
              </template>

              <template #cell(symbol)="data">
                <div class="font-italic overflow-hidden text-truncate">
                  <b-link
                    :href="'/Genes/' + data.item.hgnc_id"
                    target="_blank"
                  >
                    <b-badge
                      v-b-tooltip.hover.leftbottom
                      pill
                      variant="success"
                      :title="data.item.hgnc_id"
                    >
                      {{ data.item.symbol }}
                    </b-badge>
                  </b-link>
                </div>
              </template>

              <template #cell(disease_ontology_name)="data">
                <div class="overflow-hidden text-truncate">
                  <b-link
                    :href="
                      '/Ontology/' +
                        data.item.disease_ontology_id_version.replace(/_.+/g, '')
                    "
                    target="_blank"
                  >
                    <b-badge
                      v-b-tooltip.hover.leftbottom
                      pill
                      variant="secondary"
                      :title="
                        data.item.disease_ontology_name +
                          '; ' +
                          data.item.disease_ontology_id_version
                      "
                    >
                      {{ truncate(data.item.disease_ontology_name, 40) }}
                    </b-badge>
                  </b-link>
                </div>
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <div class="overflow-hidden text-truncate">
                  <b-badge
                    v-b-tooltip.hover.leftbottom
                    pill
                    variant="info"
                    class="justify-content-md-center"
                    size="1.3em"
                    :title="
                      data.item.hpo_mode_of_inheritance_term_name +
                        ' (' +
                        data.item.hpo_mode_of_inheritance_term +
                        ')'
                    "
                  >
                    {{
                      inheritance_short_text[
                        data.item.hpo_mode_of_inheritance_term_name
                      ]
                    }}
                  </b-badge>
                </div>
              </template>

              <template #cell(ndd_phenotype_word)="data">
                <div class="overflow-hidden text-truncate">
                  <b-avatar
                    v-b-tooltip.hover.left
                    size="1.4em"
                    :icon="ndd_icon[data.item.ndd_phenotype_word]"
                    :variant="ndd_icon_style[data.item.ndd_phenotype_word]"
                    :title="ndd_icon_text[data.item.ndd_phenotype_word]"
                  />
                </div>
              </template>

              <template #cell(review_date)="data">
                <div>
                  <b-icon
                    icon="pen"
                    font-scale="0.7"
                  />
                  <b-badge
                    v-b-tooltip.hover.right
                    :variant="data_age_style[dateYearAge(data.item.review_date, 3)]"
                    :title="data_age_text[dateYearAge(data.item.review_date, 3)]"
                    class="ml-1"
                  >
                    {{ data.item.review_date.substring(0,10) }}
                  </b-badge>
                </div>
              </template>

              <template #cell(review_user_name)="data">
                <div>
                  <b-icon
                    :icon="user_icon[data.item.review_user_role]"
                    :variant="user_style[data.item.review_user_role]"
                    font-scale="1.0"
                  />
                  <b-badge
                    v-b-tooltip.hover.right
                    :variant="user_style[data.item.review_user_role]"
                    :title="data.item.review_user_role"
                    class="ml-1"
                  >
                    {{ data.item.review_user_name }}
                  </b-badge>
                </div>
              </template>
            </b-table>
          </b-card>
        </b-col>
      </b-row>

      <!-- 1) Review modal -->
      <b-modal
        :id="reviewModal.id"
        :ref="reviewModal.id"
        size="xl"
        centered
        ok-title="Submit"
        no-close-on-esc
        no-close-on-backdrop
        header-bg-variant="dark"
        header-text-variant="light"
        :busy="loading_review_modal"
        @ok="submitReviewChange"
      >
        <template #modal-title>
          <h4>
            Modify review for entity:
            <b-link
              :href="'/Entities/' + review_info.entity_id"
              target="_blank"
            >
              <b-badge variant="primary">
                sysndd:{{ review_info.entity_id }}
              </b-badge>
            </b-link>
            <b-link
              :href="'/Genes/' + entity_info.symbol"
              target="_blank"
            >
              <b-badge
                v-b-tooltip.hover.leftbottom
                pill
                variant="success"
                :title="entity_info.hgnc_id"
              >
                {{ entity_info.symbol }}
              </b-badge>
            </b-link>
            <b-link
              :href="
                '/Ontology/' +
                  entity_info.disease_ontology_id_version.replace(/_.+/g, '')
              "
              target="_blank"
            >
              <b-badge
                v-b-tooltip.hover.leftbottom
                pill
                variant="secondary"
                :title="
                  entity_info.disease_ontology_name +
                    '; ' +
                    entity_info.disease_ontology_id_version
                "
              >
                {{ truncate(entity_info.disease_ontology_name, 40) }}
              </b-badge>
            </b-link>
            <b-badge
              v-b-tooltip.hover.leftbottom
              pill
              variant="info"
              class="justify-content-md-center"
              size="1.3em"
              :title="
                entity_info.hpo_mode_of_inheritance_term_name +
                  ' (' +
                  entity_info.hpo_mode_of_inheritance_term +
                  ')'
              "
            >
              {{
                inheritance_short_text[
                  entity_info.hpo_mode_of_inheritance_term_name
                ]
              }}
            </b-badge>
          </h4>
        </template>

        <template #modal-footer="{ ok, cancel }">
          <div class="w-100">
            <p class="float-left">
              Review by:
              <b-icon
                :icon="user_icon[review_info.review_user_role]"
                :variant="user_style[review_info.review_user_role]"
                font-scale="1.0"
              />
              <b-badge
                :variant="user_style[review_info.review_user_role]"
                class="ml-1"
              >
                {{ review_info.review_user_name }}
              </b-badge>
              <b-badge
                :variant="user_style[review_info.review_user_role]"
                class="ml-1"
              >
                {{ review_info.review_user_role }}
              </b-badge>
              <b-badge
                variant="dark"
                class="ml-1"
              >
                {{ review_info.review_date }}
              </b-badge>
            </p>

            <!-- Emulate built in modal footer ok and cancel button actions -->
            <b-button
              variant="primary"
              class="float-right mr-2"
              @click="ok()"
            >
              Save review
            </b-button>
            <b-button
              variant="secondary"
              class="float-right mr-2"
              @click="cancel()"
            >
              Cancel
            </b-button>
          </div>
        </template>

        <b-overlay
          :show="loading_review_modal"
          rounded="sm"
        >
          <b-form
            ref="form"
            @submit.stop.prevent="submitReviewChange"
          >
            <!-- Synopsis textarea -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-textarea-synopsis"
            >Synopsis</label>

            <b-badge
              id="popover-badge-help-synopsis"
              pill
              href="#"
              variant="info"
            >
              <b-icon icon="question-circle-fill" />
            </b-badge>

            <b-popover
              target="popover-badge-help-synopsis"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Synopsis instructions
              </template>
              Short summary for this disease entity. Please include information
              on: <br>
              <strong>a)</strong> approximate number of patients described in
              literature, <br>
              <strong>b)</strong> nature of reported variants, <br>
              <strong>c)</strong> severity of intellectual disability, <br>
              <strong>d)</strong> further phenotypic aspects (if possible with
              frequencies), <br>
              <strong>e)</strong> any valuable further information (e.g.
              genotype-phenotype correlations).<br>
            </b-popover>

            <b-form-textarea
              id="review-textarea-synopsis"
              v-model="review_info.synopsis"
              rows="3"
              size="sm"
            />
            <!-- Synopsis textarea -->

            <!-- Phenotype select -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-phenotype-select"
            >Phenotypes</label>

            <b-badge
              id="popover-badge-help-phenotypes"
              pill
              href="#"
              variant="info"
            >
              <b-icon icon="question-circle-fill" />
            </b-badge>

            <b-popover
              target="popover-badge-help-phenotypes"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Phenotypes instructions
              </template>
              Add or remove associated phenotypes. Only phenotypes that occur in
              20% or more of affected individuals should be included. Please
              also include information on severity of ID.
            </b-popover>

            <treeselect
              id="review-phenotype-select"
              v-model="select_phenotype"
              :multiple="true"
              :flat="true"
              :options="phenotypes_options"
              :normalizer="normalizePhenotypes"
              required
            />
            <!-- Phenotype select -->

            <!-- Variation ontology select -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-variation-select"
            >Variation ontology</label>

            <b-badge
              id="popover-badge-help-variation"
              pill
              href="#"
              variant="info"
            >
              <b-icon icon="question-circle-fill" />
            </b-badge>

            <b-popover
              target="popover-badge-help-variation"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Variation instructions
              </template>
              Please select or deselect the types of variation associated with the disease entity.
              <br>
              Minimum information should include <strong>“protein truncating variation”</strong> and/or
              <strong>“non-synonymous variation”</strong>.
              <br>
              If known, please also select the functional impact of these variations,
              i.e. if there is a protein <strong>"loss-of-function"</strong> or <strong>"gain-of-function"</strong>.
              <br>
            </b-popover>

            <treeselect
              id="review-variation-select"
              v-model="select_variation"
              :multiple="true"
              :flat="true"
              :options="variation_ontology_options"
              :normalizer="normalizeVariationOntology"
              required
            />
            <!-- Variation ontology select -->

            <!-- publications tag form with links out -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-publications-select"
            >Publications</label>

            <b-badge
              id="popover-badge-help-publications"
              pill
              href="#"
              variant="info"
            >
              <b-icon icon="question-circle-fill" />
            </b-badge>

            <b-popover
              target="popover-badge-help-publications"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Publications instructions
              </template>
              No complete catalog of entity-related literature required.
              <br>
              If information in the clinical synopsis is not only based on OMIM
              entries, please include PMID of the article(s) used as a source
              for the clinical synopsis. <br>
              - Input is only valid when starting with
              <strong>"PMID:"</strong> followed by a number
            </b-popover>

            <b-form-tags
              v-model="select_additional_references"
              input-id="review-literature-select"
              no-outer-focus
              class="my-0"
              separator=",;"
              :tag-validator="tagValidatorPMID"
              remove-on-delete
            >
              <template
                v-slot="{ tags, inputAttrs, inputHandlers, addTag, removeTag }"
              >
                <b-input-group class="my-0">
                  <b-form-input
                    v-bind="inputAttrs"
                    placeholder="Enter PMIDs separated by comma or semicolon"
                    class="form-control"
                    size="sm"
                    v-on="inputHandlers"
                  />
                  <b-input-group-append>
                    <b-button
                      variant="secondary"
                      size="sm"
                      @click="addTag()"
                    >
                      Add
                    </b-button>
                  </b-input-group-append>
                </b-input-group>

                <div class="d-inline-block">
                  <h6>
                    <b-form-tag
                      v-for="tag in tags"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      @remove="removeTag(tag)"
                    >
                      <b-link
                        :href="
                          'https://pubmed.ncbi.nlm.nih.gov/' +
                            tag.replace('PMID:', '')
                        "
                        target="_blank"
                        class="text-light"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.9"
                        />
                        {{ tag }}
                      </b-link>
                    </b-form-tag>
                  </h6>
                </div>
              </template>
            </b-form-tags>
            <!-- publications tag form with links out -->

            <!-- genereviews tag form with links out -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-genereviews-select"
            >Genereviews</label>

            <b-badge
              id="popover-badge-help-genereviews"
              pill
              href="#"
              variant="info"
            >
              <b-icon icon="question-circle-fill" />
            </b-badge>

            <b-popover
              target="popover-badge-help-genereviews"
              variant="info"
              triggers="focus"
            >
              <template #title>
                GeneReviews instructions
              </template>
              Please add PMID for GeneReview article if available for this
              entity. <br>
              - Input is only valid when starting with
              <strong>"PMID:"</strong> followed by a number
            </b-popover>

            <b-form-tags
              v-model="select_gene_reviews"
              input-id="review-genereviews-select"
              no-outer-focus
              class="my-0"
              separator=",;"
              :tag-validator="tagValidatorPMID"
              remove-on-delete
            >
              <template
                v-slot="{ tags, inputAttrs, inputHandlers, addTag, removeTag }"
              >
                <b-input-group class="my-0">
                  <b-form-input
                    v-bind="inputAttrs"
                    placeholder="Enter PMIDs separated by comma or semicolon"
                    class="form-control"
                    size="sm"
                    v-on="inputHandlers"
                  />
                  <b-input-group-append>
                    <b-button
                      variant="secondary"
                      size="sm"
                      @click="addTag()"
                    >
                      Add
                    </b-button>
                  </b-input-group-append>
                </b-input-group>

                <div class="d-inline-block">
                  <h6>
                    <b-form-tag
                      v-for="tag in tags"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      @remove="removeTag(tag)"
                    >
                      <b-link
                        :href="
                          'https://pubmed.ncbi.nlm.nih.gov/' +
                            tag.replace('PMID:', '')
                        "
                        target="_blank"
                        class="text-light"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.9"
                        />
                        {{ tag }}
                      </b-link>
                    </b-form-tag>
                  </h6>
                </div>
              </template>
            </b-form-tags>
            <!-- genereviews tag form with links out -->

            <!-- Review comment textarea -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-textarea-comment"
            >Comment</label>
            <b-form-textarea
              id="review-textarea-comment"
              v-model="review_info.comment"
              rows="2"
              size="sm"
              placeholder="Additional comments to this entity relevant for the curator."
            />
            <!-- Review comment textarea -->
          </b-form>
        </b-overlay>
      </b-modal>
      <!-- 1) Review modal -->

      <!-- 2) Status modal -->
      <b-modal
        :id="statusModal.id"
        :ref="statusModal.id"
        size="lg"
        centered
        ok-title="Submit"
        no-close-on-esc
        no-close-on-backdrop
        header-bg-variant="dark"
        header-text-variant="light"
        :busy="loading_status_modal"
        @ok="submitStatusChange"
      >
        <template #modal-title>
          <h4>
            Modify status for entity:
            <b-link
              :href="'/Entities/' + status_info.entity_id"
              target="_blank"
            >
              <b-badge variant="primary">
                sysndd:{{ status_info.entity_id }}
              </b-badge>
            </b-link>
            <b-link
              :href="'/Genes/' + entity_info.symbol"
              target="_blank"
            >
              <b-badge
                v-b-tooltip.hover.leftbottom
                pill
                variant="success"
                :title="entity_info.hgnc_id"
              >
                {{ entity_info.symbol }}
              </b-badge>
            </b-link>
            <b-link
              :href="
                '/Ontology/' +
                  entity_info.disease_ontology_id_version.replace(/_.+/g, '')
              "
              target="_blank"
            >
              <b-badge
                v-b-tooltip.hover.leftbottom
                pill
                variant="secondary"
                :title="
                  entity_info.disease_ontology_name +
                    '; ' +
                    entity_info.disease_ontology_id_version
                "
              >
                {{ truncate(entity_info.disease_ontology_name, 40) }}
              </b-badge>
            </b-link>
            <b-badge
              v-b-tooltip.hover.leftbottom
              pill
              variant="info"
              class="justify-content-md-center"
              size="1.3em"
              :title="
                entity_info.hpo_mode_of_inheritance_term_name +
                  ' (' +
                  entity_info.hpo_mode_of_inheritance_term +
                  ')'
              "
            >
              {{
                inheritance_short_text[
                  entity_info.hpo_mode_of_inheritance_term_name
                ]
              }}
            </b-badge>
          </h4>
        </template>

        <template #modal-footer="{ ok, cancel }">
          <div class="w-100">
            <p class="float-left">
              Status by:
              <b-icon
                :icon="user_icon[status_info.status_user_role]"
                :variant="user_style[status_info.status_user_role]"
                font-scale="1.0"
              />
              <b-badge
                :variant="user_style[status_info.status_user_role]"
                class="ml-1"
              >
                {{ status_info.status_user_name }}
              </b-badge>
              <b-badge
                :variant="user_style[status_info.status_user_role]"
                class="ml-1"
              >
                {{ status_info.status_user_role }}
              </b-badge>
              <b-badge
                variant="dark"
                class="ml-1"
              >
                {{ status_info.status_date }}
              </b-badge>
            </p>

            <!-- Emulate built in modal footer ok and cancel button actions -->
            <b-button
              variant="primary"
              class="float-right mr-2"
              @click="ok()"
            >
              Save status
            </b-button>
            <b-button
              variant="secondary"
              class="float-right mr-2"
              @click="cancel()"
            >
              Cancel
            </b-button>
          </div>
        </template>

        <b-overlay
          :show="loading_status_modal"
          rounded="sm"
        >
          <b-form
            ref="form"
            @submit.stop.prevent="submitStatusChange"
          >
            <!-- Status select -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="status-select"
            >Status</label>

            <b-badge
              id="popover-badge-help-status"
              pill
              href="#"
              variant="info"
            >
              <b-icon icon="question-circle-fill" />
            </b-badge>

            <b-popover
              target="popover-badge-help-status"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Status instructions
              </template>
              Please refer to the curation manual for details on the categories.
            </b-popover>

            <treeselect
              id="status-select"
              v-model="status_info.category_id"
              :multiple="false"
              :options="status_options"
              :normalizer="normalizeStatus"
            />
            <!-- Status select -->

            <!-- Suggest removal switch -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="removeSwitch"
            >Removal</label>

            <b-badge
              id="popover-badge-help-removal"
              pill
              href="#"
              variant="info"
            >
              <b-icon icon="question-circle-fill" />
            </b-badge>

            <b-popover
              target="popover-badge-help-removal"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Removal instructions
              </template>
              SysNDD does not forget, meaning that entities will not be deleted
              but they can be deactivated. Deactivated entities will not be
              displayed on the website. Typically duplicate entities should be
              deactivated especially if there is a more specific disease name.
            </b-popover>

            <div class="custom-control custom-switch">
              <input
                id="removeSwitch"
                v-model="status_info.problematic"
                type="checkbox"
                button-variant="info"
                class="custom-control-input"
              >
              <label
                class="custom-control-label"
                for="removeSwitch"
              >Suggest removal</label>
            </div>
            <!-- Suggest removal switch -->

            <label
              class="mr-sm-2 font-weight-bold"
              for="status-textarea-comment"
            >Comment</label>
            <b-form-textarea
              id="status-textarea-comment"
              v-model="status_info.comment"
              rows="2"
              size="sm"
              placeholder="Why should this entities status be changed."
            />
          </b-form>
        </b-overlay>
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
          <h4>
            Entity:
            <b-badge variant="primary">
              {{ submitModal.title }}
            </b-badge>
          </h4>
        </template>

        You have finished the re-review of this entity and
        <span class="font-weight-bold">want to submit it</span>?
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
          <h4>
            Entity:
            <b-badge variant="primary">
              {{ approveModal.title }}
            </b-badge>
          </h4>
        </template>
        What should be approved ?

        <div class="custom-control custom-switch">
          <input
            id="approveReviewSwitch"
            v-model="review_approved"
            type="checkbox"
            button-variant="info"
            class="custom-control-input"
          >
          <label
            class="custom-control-label"
            for="approveReviewSwitch"
          >Review</label>
        </div>

        <div class="custom-control custom-switch">
          <input
            id="approveStatusSwitch"
            v-model="status_approved"
            type="checkbox"
            button-variant="info"
            class="custom-control-input"
          >
          <label
            class="custom-control-label"
            for="approveStatusSwitch"
          >Status</label>
        </div>

        <div>
          <b-button
            size="sm"
            variant="warning"
            @click="handleUnsetSubmission(), hideModal(approveModal.id)"
          >
            <b-icon
              icon="unlock"
              font-scale="1.0"
            /> Unsubmit
          </b-button>
        </div>
      </b-modal>
      <!-- 4) Approve modal -->
    </b-container>
  </div>
</template>

<script>
// import the Treeselect component
import Treeselect from '@riophae/vue-treeselect';
// import the Treeselect styles
import '@riophae/vue-treeselect/dist/vue-treeselect.css';

import toastMixin from '@/assets/js/mixins/toastMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';
import textMixin from '@/assets/js/mixins/textMixin';

// Import the utilities file
import Utils from '@/assets/js/utils';

import Review from '@/assets/js/classes/submission/submissionReview';
import Status from '@/assets/js/classes/submission/submissionStatus';
import Phenotype from '@/assets/js/classes/submission/submissionPhenotype';
import Variation from '@/assets/js/classes/submission/submissionVariation';
import Literature from '@/assets/js/classes/submission/submissionLiterature';

export default {
  name: 'Review',
  // register the Treeselect component
  components: { Treeselect },
  mixins: [toastMixin, colorAndSymbolsMixin, textMixin],
  data() {
    return {
      items: [],
      fields: [
        {
          key: 'entity_id',
          label: 'Entity',
          sortable: true,
          sortDirection: 'desc',
          class: 'text-left',
        },
        {
          key: 'symbol',
          label: 'Gene',
          sortable: true,
          filterable: true,
          sortDirection: 'desc',
          class: 'text-left',
        },
        {
          key: 'disease_ontology_name',
          label: 'Disease',
          sortable: true,
          class: 'text-left',
          sortByFormatted: true,
          filterByFormatted: true,
        },
        {
          key: 'hpo_mode_of_inheritance_term_name',
          label: 'Inheritance',
          sortable: true,
          class: 'text-left',
          sortByFormatted: true,
          filterByFormatted: true,
        },
        {
          key: 'ndd_phenotype_word',
          label: 'NDD',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'review_date',
          label: 'Review date',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'review_user_name',
          label: 'User',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'actions',
          label: 'Actions',
          class: 'text-left',
        },
      ],
      totalRows: 1,
      currentPage: 1,
      perPage: '10',
      pageOptions: ['10', '25', '50', '200'],
      sortBy: '',
      sortDesc: false,
      sortDirection: 'asc',
      filter: null,
      filterOn: [],
      reviewModal: {
        id: 'review-modal',
        title: '',
        content: [],
      },
      statusModal: {
        id: 'status-modal',
        title: '',
        content: [],
      },
      submitModal: {
        id: 'submit-modal',
        title: '',
        content: [],
      },
      approveModal: {
        id: 'approve-modal',
        title: '',
        content: [],
      },
      review: [{ synopsis: '' }],
      review_fields: [
        { key: 'synopsis', label: 'Clinical Synopsis', class: 'text-left' },
      ],
      status_options: [],
      status_info: new Status(),
      loading_status_modal: true,
      entity_info: {
        entity_id: 0,
        symbol: '',
        hgnc_id: '',
        disease_ontology_id_version: '',
        disease_ontology_name: '',
        hpo_mode_of_inheritance_term_name: '',
        hpo_mode_of_inheritance_term: '',
      },
      review_info: new Review(),
      select_phenotype: [],
      select_variation: [],
      phenotypes_options: [],
      variation_ontology_options: [],
      select_additional_references: [],
      select_gene_reviews: [],
      curation_selected: false,
      review_approved: false,
      status_approved: false,
      curator_mode: 0,
      loading: true,
      loading_review_modal: true,
      user: {
        user_id: [],
        user_name: [],
        email: [],
        user_role: [],
        user_created: [],
        abbreviation: [],
        orcid: [],
        exp: [],
      },
      isBusy: true,
    };
  },
  computed: {
    sortOptions() {
      // Create an options list from our fields
      return this.fields
        .filter((f) => f.sortable)
        .map((f) => ({ text: f.label, value: f.key }));
    },
  },
  watch: {
    // used to reload table when switching curator mode
    curation_selected(newVal, oldVal) {
      // watch it
      this.loadReReviewData();
    },
    select_additional_references: {
      handler(newVal) {
        const sanitizedValues = newVal.map(this.sanitizeInput);
        if (!this.arraysAreEqual(this.select_additional_references, sanitizedValues)) {
          this.select_additional_references = sanitizedValues;
        }
      },
      deep: true,
    },
    select_gene_reviews: {
      handler(newVal) {
        const sanitizedValues = newVal.map(this.sanitizeInput);
        if (!this.arraysAreEqual(this.select_gene_reviews, sanitizedValues)) {
          this.select_gene_reviews = sanitizedValues;
        }
      },
      deep: true,
    },
  },
  mounted() {
    if (localStorage.user) {
      this.user = JSON.parse(localStorage.user);
      this.curator_mode = (this.user.user_role[0] === 'Administrator')
        || (this.user.user_role[0] === 'Curator');
      console.log(this.user.user_role[0]);
      console.log(this.curator_mode);
    }
    this.loadReReviewData();
    this.loadPhenotypesList();
    this.loadVariationOntologyList();
    this.loadStatusList();
  },
  methods: {
    async loadPhenotypesList() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/list/phenotype?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.phenotypes_options = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadVariationOntologyList() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/list/variation_ontology?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.variation_ontology_options = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadStatusList() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/list/status?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.status_options = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    normalizePhenotypes(node) {
      return {
        id: node.id,
        label: node.label,
      };
    },
    normalizeStatus(node) {
      return {
        id: node.category_id,
        label: node.category,
      };
    },
    normalizeVariationOntology(node) {
      return {
        id: node.id,
        label: node.label,
      };
    },
    onFiltered(filteredItems) {
      // Trigger pagination to update the number of buttons/pages due to filtering
      this.totalRows = filteredItems.length;
      this.currentPage = 1;
    },
    resetApproveModal() {
      this.status_approved = false;
      this.review_approved = false;
    },
    infoReview(item, index, button) {
      this.reviewModal.title = `sysndd:${item.entity_id}`;
      this.getEntity(item.entity_id);
      this.loadReviewInfo(item.review_id, item.re_review_review_saved);
      this.$root.$emit('bv::show::modal', this.reviewModal.id, button);
    },
    infoStatus(item, index, button) {
      this.statusModal.title = `sysndd:${item.entity_id}`;
      this.getEntity(item.entity_id);
      this.loadStatusInfo(item.status_id, item.re_review_status_saved);
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
      this.isBusy = true;
      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/re_review_table?curate=${
        this.curation_selected}`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });

        this.items = response.data;
        this.totalRows = response.data.length;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.isBusy = false;
      this.loading = false;
    },
    async getEntity(entity_input) {
      const apiGetURL = `${process.env.VUE_APP_API_URL
      }/api/entity?filter=equals(entity_id,${
        entity_input
      })`;

      try {
        const response = await this.axios.get(apiGetURL);
        // assign to local variable
        [this.entity_info] = response.data.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadReviewInfo(review_id, re_review_review_saved) {
      this.loading_review_modal = true;

      const apiGetReviewURL = `${process.env.VUE_APP_API_URL}/api/review/${review_id}`;
      const apiGetPhenotypesURL = `${process.env.VUE_APP_API_URL
      }/api/review/${
        review_id
      }/phenotypes`;
      const apiGetVariationURL = `${process.env.VUE_APP_API_URL}/api/review/${review_id}/variation`;
      const apiGetPublicationsURL = `${process.env.VUE_APP_API_URL
      }/api/review/${
        review_id
      }/publications`;

      try {
        const response_review = await this.axios.get(apiGetReviewURL);
        const response_phenotypes = await this.axios.get(apiGetPhenotypesURL);
        const response_variation = await this.axios.get(apiGetVariationURL);
        const response_publications = await this.axios.get(apiGetPublicationsURL);

        // define phenotype specific attributes as constants from response
        const new_phenotype = response_phenotypes.data.map((item) => new Phenotype(item.phenotype_id, item.modifier_id));
        this.select_phenotype = response_phenotypes.data.map((item) => `${item.modifier_id}-${item.phenotype_id}`);

        // define variation specific attributes as constants from response
        const new_variation = response_variation.data.map((item) => new Variation(item.vario_id, item.modifier_id));
        this.select_variation = response_variation.data.map((item) => `${item.modifier_id}-${item.vario_id}`);

        // define publication specific attributes as constants from response
        const literature_gene_reviews = response_publications.data
          .filter((item) => item.publication_type === 'gene_review')
          .map((item) => item.publication_id);

        const literature_additional_references = response_publications.data
          .filter((item) => item.publication_type === 'additional_references')
          .map((item) => item.publication_id);

        this.select_additional_references = literature_additional_references;
        this.select_gene_reviews = literature_gene_reviews;

        const new_literature = new Literature(
          literature_additional_references,
          literature_gene_reviews,
        );

        // compose review
        this.review_info = new Review(
          response_review.data[0].synopsis,
          new_literature,
          new_phenotype,
          new_variation,
          response_review.data[0].comment,
        );

        this.review_info.review_id = response_review.data[0].review_id;
        this.review_info.entity_id = response_review.data[0].entity_id;
        this.review_info.review_user_name = response_review.data[0].review_user_name;
        this.review_info.review_user_role = response_review.data[0].review_user_role;
        this.review_info.review_date = response_review.data[0].review_date;
        this.review_info.re_review_review_saved = re_review_review_saved;

        this.loading_review_modal = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadStatusInfo(status_id, re_review_status_saved) {
      this.loading_status_modal = true;

      const apiGetURL = `${process.env.VUE_APP_API_URL}/api/status/${status_id}`;

      try {
        const response = await this.axios.get(apiGetURL);

        // compose entity
        this.status_info = new Status(
          response.data[0].category_id,
          response.data[0].comment,
          response.data[0].problematic,
        );

        this.status_info.status_id = response.data[0].status_id;
        this.status_info.entity_id = response.data[0].entity_id;
        this.status_info.status_user_name = response.data[0].status_user_name;
        this.status_info.status_user_role = response.data[0].status_user_role;
        this.status_info.status_date = response.data[0].status_date;
        this.status_info.re_review_status_saved = re_review_status_saved;

        this.loading_status_modal = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async submitStatusChange() {
      const status_saved = this.status_info.re_review_status_saved;

      // remove user info from status object
      // TODO: handle this server side to make it more robust
      this.status_info.status_user_name = null;
      this.status_info.status_user_role = null;
      this.status_info.re_review_status_saved = null;

      if (status_saved === 1) {
        // perform update PUT request
        try {
          const apiUrl = `${process.env.VUE_APP_API_URL}/api/status/update?re_review=true`;
          const response = await this.axios.put(
            apiUrl,
            { status_json: this.status_info },
            {
              headers: {
                Authorization: `Bearer ${localStorage.getItem('token')}`,
              },
            },
          );

          this.makeToast(
            `${'The new status for this entity has been submitted '
              + '(status '}${
              response.status
            } (${
              response.statusText
            }).`,
            'Success',
            'success',
          );
          this.resetForm();
          this.loadReReviewData();
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
        }
      } else {
        const apiUrl = `${process.env.VUE_APP_API_URL}/api/status/create?re_review=true`;
        // perform update POST request
        try {
          const response = await this.axios.post(
            apiUrl,
            { status_json: this.status_info },
            {
              headers: {
                Authorization: `Bearer ${localStorage.getItem('token')}`,
              },
            },
          );

          this.makeToast(
            `${'The new status for this entity has been submitted '
              + '(status '}${
              response.status
            } (${
              response.statusText
            }).`,
            'Success',
            'success',
          );
          this.resetForm();
          this.loadReReviewData();
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
        }
      }
    },
    async submitReviewChange() {
      this.isBusy = true;

      const review_saved = this.review_info.re_review_review_saved;

      // remove user info from review object
      // TODO: handle this server side to make it more robust
      this.review_info.review_user_name = null;
      this.review_info.review_user_role = null;
      this.review_info.re_review_review_saved = null;

      // define literature specific attributes as constants from inputs
      // first clean the arrays
      const select_additional_references_clean = this.select_additional_references.map(
        (element) => this.sanitizeInput(element),
      );

      const select_gene_reviews_clean = this.select_gene_reviews.map(
        (element) => this.sanitizeInput(element),
      );

      const replace_literature = new Literature(
        select_additional_references_clean,
        select_gene_reviews_clean,
      );

      // compose phenotype specific attributes as constants from inputs
      const replace_phenotype = this.select_phenotype.map((item) => new Phenotype(item.split('-')[1], item.split('-')[0]));

      // compose variation ontology specific attributes as constants from inputs
      const replace_variation_ontology = this.select_variation.map((item) => new Variation(item.split('-')[1], item.split('-')[0]));

      // assign to object
      this.review_info.literature = replace_literature;
      this.review_info.phenotypes = replace_phenotype;
      this.review_info.variation_ontology = replace_variation_ontology;

      if (review_saved === 1) {
        const apiUrl = `${process.env.VUE_APP_API_URL}/api/review/update?re_review=true`;

        // perform update POST request
        try {
          const response = await this.axios.put(
            apiUrl,
            { review_json: this.review_info },
            {
              headers: {
                Authorization: `Bearer ${localStorage.getItem('token')}`,
              },
            },
          );

          this.makeToast(
            `${'The new review for this entity has been submitted '
              + '(status '}${
              response.status
            } (${
              response.statusText
            }).`,
            'Success',
            'success',
          );
          this.resetForm();
          this.loadReReviewData();
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
        }
      } else {
        const apiUrl = `${process.env.VUE_APP_API_URL}/api/review/create?re_review=true`;

        // perform update POST request
        try {
          const response = await this.axios.post(
            apiUrl,
            { review_json: this.review_info },
            {
              headers: {
                Authorization: `Bearer ${localStorage.getItem('token')}`,
              },
            },
          );

          this.makeToast(
            `${'The new review for this entity has been submitted '
              + '(status '}${
              response.status
            } (${
              response.statusText
            }).`,
            'Success',
            'success',
          );
          this.resetForm();
          this.loadReReviewData();
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
        }
      }
    },
    resetForm() {
      // status
      this.status_info = new Status();

      // review
      this.select_phenotype = [];
      this.select_variation = [];
      this.select_additional_references = [];
      this.select_gene_reviews = [];
      this.entity_info = {
        entity_id: 0,
        symbol: '',
        hgnc_id: '',
        disease_ontology_id_version: '',
        disease_ontology_name: '',
        hpo_mode_of_inheritance_term_name: '',
        hpo_mode_of_inheritance_term: '',
      };
      this.review_info = new Review();
    },
    async handleSubmitOk(bvModalEvt) {
      const re_review_submission = {};

      re_review_submission.re_review_entity_id = this.entity[0].re_review_entity_id;
      re_review_submission.re_review_submitted = 1;

      const apiUrl = `${process.env.VUE_APP_API_URL}/api/re_review/submit`;
      try {
        const response = await this.axios.put(
          apiUrl,
          { submit_json: re_review_submission },
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.loadReReviewData();
    },
    async handleApproveOk(bvModalEvt) {
      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/re_review/approve/${
        this.entity[0].re_review_entity_id
      }?status_ok=${
        this.status_approved
      }&review_ok=${
        this.review_approved}`;

      try {
        const response = await this.axios.put(
          apiUrl,
          {},
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.resetApproveModal();
      this.loadReReviewData();
    },
    async handleUnsetSubmission(bvModalEvt) {
      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/re_review/unsubmit/${
        this.entity[0].re_review_entity_id}`;

      try {
        const response = await this.axios.put(
          apiUrl,
          {},
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.resetApproveModal();
      this.loadReReviewData();
    },
    async newBatchApplication() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/re_review/batch/apply`;

      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.makeToast('Application send.', 'Success', 'success');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    tagValidatorPMID(tag) {
      // Individual PMID tag validator function
      const tag_copy = tag.replace(/\s+/g, '');
      return (
        !Number.isNaN(Number(tag_copy.replaceAll('PMID:', '').replaceAll(' ', '')))
        && tag_copy.includes('PMID:')
        && tag_copy.replace('PMID:', '').length > 4
        && tag_copy.replace('PMID:', '').length < 9
      );
    },
    saved(any_id) {
      // TODO: implement this server side and with real logic :D
      // check if id is new
      let number_return = 0;
      if (any_id <= 3650) {
        number_return = 0;
      } else {
        number_return = 1;
      }
      return number_return;
    },
    // Function to truncate a string to a specified length.
    // If the string is longer than the specified length, it adds '...' to the end.
    // imported from utils.js
    truncate(str, n) {
      // Use the utility function here
      return Utils.truncate(str, n);
    },
    dateYearAge(date, rounding) {
      // calculate the age based on the difference from current date
      // round to nearest input argument "rounding"
      return Math.round((Date.now() - Date.parse(date)) / 1000 / 60 / 60 / 24 / 365 / rounding) * rounding;
    },
    hideModal(id) {
      this.$root.$emit('bv::hide::modal', id);
    },
    /**
     * Sanitizes the input by removing extra white spaces, especially for PubMed IDs.
     * Expected input format: "PMID: 123456"
     * Output format: "PMID:123456"
     * @param {String} input - The input string to be sanitized.
     * @return {String} The sanitized string.
     */
    sanitizeInput(input) {
      if (!input) return '';

      // Split the input based on ':' (e.g., "PMID: 123456")
      const parts = input.split(':');

      // Check if the input format is as expected
      if (parts.length !== 2 || !parts[0].trim().startsWith('PMID')) return input;

      // Trim whitespace from both parts and rejoin them
      return `${parts[0].trim()}:${parts[1].trim()}`;
    },
    arraysAreEqual(array1, array2) {
      if (array1.length !== array2.length) {
        return false;
      }
      return array1.every((value, index) => value === array2[index]);
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
.badge-container .badge {
  width: 170px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

:deep(.vue-treeselect__menu) {
  outline: 1px solid red;
  color: blue;
}
</style>
