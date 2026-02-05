<template>
  <div class="container-fluid">
    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />
    <BContainer v-else fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="8">
          <div class="accordion" role="tablist">
            <BCard no-body class="mb-1">
              <BCardHeader header-tag="header" class="p-1" role="tab">
                <BButton v-b-toggle.accordion-6 block variant="info" class="text-start">
                  Instructions
                </BButton>
              </BCardHeader>
              <BCollapse id="accordion-6" visible accordion="my-accordion" role="tabpanel">
                <BCardBody>
                  <BContainer fluid="sm" class="text-start py-2">
                    <BRow>
                      <BCol md="12">
                        <span class="font-weight-bold"> 1. Curation criteria </span>
                      </BCol>
                    </BRow>
                    <BRow>
                      <BCol md="12">
                        Please read the Curation criteria at
                        <BLink :href="DOCS_URLS.CURATION_CRITERIA">
                          The SysNDD Documentation - Chapter | 5 Curation criteria </BLink
                        >.<br /><br />
                      </BCol>
                    </BRow>

                    <BRow>
                      <BCol md="12">
                        <span class="font-weight-bold"> 2. Re-review instructions </span>
                      </BCol>
                    </BRow>
                    <BRow>
                      <BCol md="12">
                        Please read the Re-review instructions at
                        <BLink :href="DOCS_URLS.RE_REVIEW_INSTRUCTIONS">
                          The SysNDD Documentation - Chapter | 6 Re-review instructions </BLink
                        >.<br /><br />
                      </BCol>
                    </BRow>

                    <BRow>
                      <BCol md="12">
                        <span class="font-weight-bold"> 3. Tutorial videos </span>
                      </BCol>
                    </BRow>
                    <BRow>
                      <BCol md="12">
                        Please watch the tutorial videos at
                        <BLink :href="DOCS_URLS.TUTORIAL_VIDEOS">
                          The SysNDD Documentation - Chapter | 7 Tutorial videos </BLink
                        >.<br /><br />
                      </BCol>
                    </BRow>
                  </BContainer>
                </BCardBody>
              </BCollapse>
            </BCard>
          </div>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import { DOCS_URLS } from '@/constants/docs';

export default {
  name: 'ReviewInstructions',
  setup() {
    useHead({
      title: 'Instructions',
      meta: [
        {
          name: 'description',
          content:
            'The Instructions view contains information about the SysNDD re-review curation effort.',
        },
      ],
    });

    return {
      DOCS_URLS,
    };
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
