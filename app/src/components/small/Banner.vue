<!-- Banner.vue -->
<template>
  <div v-if="!banner_acknowledged">
    <!-- Banner display code -->
    <b-alert
      class="position-fixed fixed-bottom m-0 rounded-0 text-start"
      style="z-index: 2000; font-size: 0.8rem"
      variant="danger"
      :show="!banner_acknowledged"
    >
      <b-row>
        <b-col md="1">
          <b-icon
            icon="exclamation-triangle"
            font-scale="2.0"
          />
        </b-col>
        <b-col md="10">
          <h6 class="alert-heading">
            Usage policy
          </h6>
          The information on this website is not intended for direct diagnostic
          use or medical decision-making without review by a genetics
          professional. Individuals should not change their health behavior on
          the basis of information contained on this website. SysNDD does not
          independently verify the information gathered from external sources.
          If you have questions about specific gene-disease claims, please
          contact the respective primary sources. If you have questions about
          the representation of the data on this website, please contact support
          [at] sysndd.org.<br><br>

          <h6 class="alert-heading">
            Data privacy
          </h6>
          The SysNDD website does not use cookies and tries to be completely
          stateless for regular users. Our parent domain unibe.ch uses cookies
          which we do not control (<b-link
            href="https://www.unibe.ch/legal_notice/index_eng.html"
            target="_blank"
          >
            see legal notice here
          </b-link>). Server side programs keep error logs to improve SysNDD. These are
          deleted regularly.
        </b-col>
        <b-col md="1">
          <b-button
            variant="outline-dark"
            size="sm"
            @click="acknowledgeBanner()"
          >
            Dismiss
          </b-button>
        </b-col>
      </b-row>
    </b-alert>
  </div>
</template>

<script>
export default {
  data() {
    return {
      banner_acknowledged: localStorage.getItem('banner_acknowledged'),
    };
  },
  methods: {
    // Function to acknowledge the banner.
    // This sets a value in localStorage to remember the user's action.
    acknowledgeBanner() {
      localStorage.setItem('banner_acknowledged', true);
      this.banner_acknowledged = localStorage.getItem('banner_acknowledged');
    },
  },
};
</script>
