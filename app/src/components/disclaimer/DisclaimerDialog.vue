<!-- components/disclaimer/DisclaimerDialog.vue -->
<!-- Persistent disclaimer modal — WCAG 2.2 AA compliant -->
<template>
  <BModal
    v-model="dialogVisible"
    size="lg"
    centered
    no-close-on-backdrop
    no-close-on-esc
    no-header
    no-footer
    body-class="p-0"
    role="alertdialog"
    aria-labelledby="disclaimer-title"
    aria-describedby="disclaimer-content"
  >
    <div class="disclaimer-dialog">
      <!-- Header -->
      <div class="disclaimer-header">
        <i class="bi bi-exclamation-triangle-fill disclaimer-header__icon" aria-hidden="true" />
        <h5
          id="disclaimer-title"
          class="disclaimer-header__title mb-0"
        >
          Usage Policy &amp; Data Privacy
        </h5>
      </div>

      <!-- Content -->
      <div
        id="disclaimer-content"
        class="disclaimer-body"
      >
        <section class="disclaimer-section">
          <h6 class="disclaimer-section__heading">
            <i class="bi bi-shield-exclamation" aria-hidden="true" />
            Usage Policy
          </h6>
          <p class="disclaimer-section__text">
            The information on this website is not intended for direct diagnostic
            use or medical decision-making without review by a genetics
            professional. Individuals should not change their health behavior on
            the basis of information contained on this website.
          </p>
          <ul class="disclaimer-section__list">
            <li>
              SysNDD does not independently verify the information gathered from
              external sources.
            </li>
            <li>
              If you have questions about specific gene-disease claims, please
              contact the respective primary sources.
            </li>
            <li>
              If you have questions about the representation of the data on this
              website, please contact
              <strong>support [at] sysndd.org</strong>.
            </li>
          </ul>
        </section>

        <hr class="disclaimer-divider">

        <section class="disclaimer-section">
          <h6 class="disclaimer-section__heading">
            <i class="bi bi-lock" aria-hidden="true" />
            Data Privacy
          </h6>
          <p class="disclaimer-section__text">
            The SysNDD website does not use cookies and tries to be completely
            stateless for regular users. Our parent domain unibe.ch uses cookies
            which we do not control
            (<BLink
              href="https://www.unibe.ch/legal_notice/index_eng.html"
              target="_blank"
              class="disclaimer-link"
            >see legal notice here</BLink>).
            Server side programs keep error logs to improve SysNDD. These are
            deleted regularly.
          </p>
        </section>
      </div>

      <!-- Footer actions -->
      <div class="disclaimer-footer">
        <BButton
          variant="primary"
          size="md"
          :disabled="loading"
          aria-label="Acknowledge and Continue"
          @click="acknowledgeDisclaimer"
        >
          <BSpinner
            v-if="loading"
            small
            class="me-2"
          />
          <i
            v-else
            class="bi bi-check-circle me-2"
            aria-hidden="true"
          />
          Acknowledge and Continue
        </BButton>
      </div>
    </div>
  </BModal>
</template>

<script>
export default {
  name: 'DisclaimerDialog',
  props: {
    modelValue: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['update:modelValue', 'acknowledged'],
  data() {
    return {
      loading: false,
    };
  },
  computed: {
    dialogVisible: {
      get() {
        return this.modelValue;
      },
      set(value) {
        this.$emit('update:modelValue', value);
      },
    },
  },
  methods: {
    acknowledgeDisclaimer() {
      this.loading = true;
      // Brief delay for UX feedback
      setTimeout(() => {
        this.loading = false;
        this.$emit('acknowledged');
        this.dialogVisible = false;
      }, 300);
    },
  },
};
</script>

<style scoped>
.disclaimer-dialog {
  overflow: hidden;
}

.disclaimer-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1.25rem 1.5rem;
  background: linear-gradient(135deg, #fff3e0 0%, #ffe0b2 100%);
  border-bottom: 2px solid #f57c00;
}

.disclaimer-header__icon {
  font-size: 1.5rem;
  color: #f57c00;
}

.disclaimer-header__title {
  font-weight: 700;
  color: #e65100;
}

.disclaimer-body {
  padding: 1.5rem;
  max-height: 60vh;
  overflow-y: auto;
}

.disclaimer-section__heading {
  font-weight: 600;
  color: var(--medical-blue-700, #0d47a1);
  margin-bottom: 0.75rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.disclaimer-section__text {
  color: var(--neutral-800, #424242);
  line-height: 1.6;
  margin-bottom: 0.75rem;
}

.disclaimer-section__list {
  color: var(--neutral-800, #424242);
  line-height: 1.6;
  padding-left: 1.25rem;
}

.disclaimer-section__list li {
  margin-bottom: 0.5rem;
}

.disclaimer-divider {
  border-top: 1px dashed var(--neutral-300, #e0e0e0);
  margin: 1rem 0;
}

.disclaimer-link {
  color: var(--medical-blue-700, #0d47a1);
  text-decoration: underline;
}

.disclaimer-footer {
  display: flex;
  justify-content: flex-end;
  padding: 1rem 1.5rem;
  border-top: 1px solid var(--neutral-200, #eeeeee);
  background: var(--neutral-50, #fafafa);
}

@media (prefers-reduced-motion: reduce) {
  .disclaimer-body {
    scroll-behavior: auto;
  }
}
</style>
