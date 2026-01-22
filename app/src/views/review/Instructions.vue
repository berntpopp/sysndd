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
          md="8"
        >
          <div
            class="accordion"
            role="tablist"
          >
            <b-card
              no-body
              class="mb-1"
            >
              <b-card-header
                header-tag="header"
                class="p-1"
                role="tab"
              >
                <b-button
                  v-b-toggle.accordion-6
                  block
                  variant="info"
                  class="text-start"
                >
                  Instructions
                </b-button>
              </b-card-header>
              <b-collapse
                id="accordion-6"
                visible
                accordion="my-accordion"
                role="tabpanel"
              >
                <b-card-body>
                  <b-container
                    fluid="sm"
                    class="text-start py-2"
                  >
                    <b-row>
                      <b-col md="12">
                        <span class="font-weight-bold">
                          1. Curation criteria
                        </span>
                      </b-col>
                    </b-row>
                    <b-row>
                      <b-col md="12">
                        Please read the Curation criteria at <b-link href="https://berntpopp.github.io/sysndd/curation-criteria.html">
                          The SysNDD Documentation - Chapter | 5 Curation criteria
                        </b-link>.<br><br>
                      </b-col>
                    </b-row>

                    <b-row>
                      <b-col md="12">
                        <span class="font-weight-bold">
                          2. Re-review instructions
                        </span>
                      </b-col>
                    </b-row>
                    <b-row>
                      <b-col md="12">
                        Please read the Re-review instructions at <b-link href="https://berntpopp.github.io/sysndd/re-review-instructions.html">
                          The SysNDD Documentation - Chapter | 6 Re-review instructions
                        </b-link>.<br><br>
                      </b-col>
                    </b-row>

                    <b-row>
                      <b-col md="12">
                        <span class="font-weight-bold">
                          3. Tutorial videos
                        </span>
                      </b-col>
                    </b-row>
                    <b-row>
                      <b-col md="12">
                        Please watch the tutorial videos at l<b-link href="https://berntpopp.github.io/sysndd/tutorial-videos.htm">
                          The SysNDD Documentation - Chapter | 7 Tutorial videos
                        </b-link>.<br><br>
                      </b-col>
                    </b-row>
                  </b-container>
                </b-card-body>
              </b-collapse>
            </b-card>
          </div>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
export default {
  name: 'Instructions',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Instructions',
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
        content:
          'The Instructions view contains information about the SysNDD re-review curation effort.',
      },
    ],
  },
  data() {
    return {
      name: 'Instructions',
      loading: false,
    };
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
