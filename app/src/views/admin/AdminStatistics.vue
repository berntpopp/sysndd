<template>
  <div class="container-fluid">
    <b-container fluid>
      <b-row class="justify-content-md-center py-2">
        <b-col md="10">
          <h3>Admin Statistics</h3>
          <b-card
            header-tag="header"
            align="left"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
            class="mb-3"
          >
            <template #header>
              <h5 class="mb-0 text-left font-weight-bold">
                Filter Statistics
              </h5>
            </template>
            <b-form @submit.prevent="fetchStatistics">
              <b-form-group label="Start Date">
                <b-form-input
                  v-model="startDate"
                  type="date"
                />
              </b-form-group>
              <b-form-group label="End Date">
                <b-form-input
                  v-model="endDate"
                  type="date"
                />
              </b-form-group>
              <b-button
                type="submit"
                variant="primary"
              >
                Get Statistics
              </b-button>
            </b-form>
          </b-card>
        </b-col>
      </b-row>
      <b-row
        v-if="statistics"
        class="justify-content-md-center py-2"
      >
        <b-col md="10">
          <b-card
            header-tag="header"
            align="left"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
            class="mb-3"
          >
            <template #header>
              <h5 class="mb-0 text-left">
                Updates Statistics
                <small>({{ startDate }} to {{ endDate }})</small>
              </h5>
            </template>
            <p>Total new entities: <span class="stats-number">{{ statistics.total_new_entities[0] }}</span></p>
            <p>Unique genes: <span class="stats-number">{{ statistics.unique_genes[0] }}</span></p>
            <p>Average per day: <span class="stats-number">{{ statistics.average_per_day[0] }}</span></p>
          </b-card>
        </b-col>
      </b-row>
      <b-row
        v-if="reReviewStatistics"
        class="justify-content-md-center py-2"
      >
        <b-col md="10">
          <b-card
            header-tag="header"
            align="left"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
            class="mb-3"
          >
            <template #header>
              <h5 class="mb-0 text-left">
                Re-review Statistics
                <small>({{ startDate }} to {{ endDate }})</small>
              </h5>
            </template>
            <p>Total re-reviews: <span class="stats-number">{{ reReviewStatistics.total_rereviews[0] }}</span></p>
            <p>Percentage finished: <span class="stats-number">{{ reReviewStatistics.percentage_finished[0] }}%</span></p>
            <p>Average per day: <span class="stats-number">{{ reReviewStatistics.average_per_day[0] }}</span></p>
          </b-card>
        </b-col>
      </b-row>
      <b-row
        v-if="updatedReviewsStatistics"
        class="justify-content-md-center py-2"
      >
        <b-col md="10">
          <b-card
            header-tag="header"
            align="left"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
            class="mb-3"
          >
            <template #header>
              <h5 class="mb-0 text-left">
                Updated Reviews Statistics
                <small>({{ startDate }} to {{ endDate }})</small>
              </h5>
            </template>
            <p>Total updated reviews: <span class="stats-number">{{ updatedReviewsStatistics.total_updated_reviews }}</span></p>
          </b-card>
        </b-col>
      </b-row>
      <b-row
        v-if="updatedStatusesStatistics"
        class="justify-content-md-center py-2"
      >
        <b-col md="10">
          <b-card
            header-tag="header"
            align="left"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
            class="mb-3"
          >
            <template #header>
              <h5 class="mb-0 text-left">
                Updated Statuses Statistics
                <small>({{ startDate }} to {{ endDate }})</small>
              </h5>
            </template>
            <p>Total updated statuses: <span class="stats-number">{{ updatedStatusesStatistics.total_updated_statuses }}</span></p>
          </b-card>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
export default {
  data() {
    return {
      startDate: '',
      endDate: new Date().toISOString().split('T')[0], // Set default end date to today's date
      statistics: null,
      reReviewStatistics: null,
      updatedReviewsStatistics: null,
      updatedStatusesStatistics: null,
    };
  },
  methods: {
    async fetchStatistics() {
      try {
        const updatesResponse = await this.axios.get(`${process.env.VUE_APP_API_URL}/api/statistics/updates?start_date=${this.startDate}&end_date=${this.endDate}`, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.statistics = updatesResponse.data;

        const reReviewResponse = await this.axios.get(`${process.env.VUE_APP_API_URL}/api/statistics/rereview?start_date=${this.startDate}&end_date=${this.endDate}`, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.reReviewStatistics = reReviewResponse.data;

        const updatedReviewsResponse = await this.axios.get(`${process.env.VUE_APP_API_URL}/api/statistics/updated_reviews?start_date=${this.startDate}&end_date=${this.endDate}`, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.updatedReviewsStatistics = updatedReviewsResponse.data;

        const updatedStatusesResponse = await this.axios.get(`${process.env.VUE_APP_API_URL}/api/statistics/updated_statuses?start_date=${this.startDate}&end_date=${this.endDate}`, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.updatedStatusesStatistics = updatedStatusesResponse.data;
      } catch (error) {
        this.$bvToast.toast('Failed to fetch statistics', {
          title: 'Error',
          variant: 'danger',
          solid: true,
        });
      }
    },
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

  .stats-number {
    font-weight: bold;
  }

  small {
    font-size: 0.9em;
  }
</style>
