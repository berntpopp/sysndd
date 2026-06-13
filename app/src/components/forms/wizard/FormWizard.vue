<template>
  <div class="form-wizard">
    <!-- Progress Indicator -->
    <div class="wizard-progress">
      <div class="wizard-steps d-flex justify-content-between position-relative">
        <!-- Progress line background -->
        <div class="wizard-progress-line" />
        <!-- Active progress line -->
        <div class="wizard-progress-line-active" :style="{ width: progressWidth }" />

        <!-- Step indicators -->
        <div
          v-for="(step, index) in steps"
          :key="step"
          :class="[
            'wizard-step',
            {
              active: index === currentStepIndex,
              completed: index < currentStepIndex,
              clickable: index < currentStepIndex,
            },
          ]"
          role="button"
          :tabindex="index < currentStepIndex ? 0 : -1"
          :aria-current="index === currentStepIndex ? 'step' : undefined"
          @click="onStepClick(index)"
          @keydown.enter="onStepClick(index)"
        >
          <div class="step-indicator">
            <i v-if="index < currentStepIndex" class="bi bi-check" />
            <span v-else>{{ index + 1 }}</span>
          </div>
          <div class="step-label">{{ stepLabels[step] }}</div>
        </div>
      </div>
    </div>

    <!-- Step Content Area -->
    <section
      class="wizard-content"
      :aria-label="`${stepLabels[currentStep]} step ${currentStepIndex + 1} of ${totalSteps}`"
    >
      <!-- Dynamic step content -->
      <transition name="fade" mode="out-in">
        <div :key="currentStep">
          <slot :name="currentStep" />
        </div>
      </transition>
    </section>

    <!-- Navigation Footer -->
    <div class="wizard-navigation d-flex justify-content-between align-items-center">
      <!-- Back button -->
      <BButton v-if="currentStepIndex > 0" variant="outline-secondary" @click="onBack">
        <i class="bi bi-arrow-left me-2" />
        Back
      </BButton>
      <div v-else />

      <!-- Right side buttons -->
      <div class="d-flex align-items-center gap-3">
        <!-- Draft status -->
        <div v-if="showDraftStatus" class="draft-status text-muted small">
          <template v-if="isSaving">
            <BSpinner small class="me-1" />
            Saving...
          </template>
          <template v-else-if="lastSavedFormatted">
            <i class="bi bi-cloud-check me-1" />
            Draft saved {{ lastSavedFormatted }}
          </template>
        </div>

        <!-- Next / Submit button -->
        <BButton
          v-if="currentStepIndex < totalSteps - 1"
          variant="primary"
          :disabled="!canProceed"
          @click="onNext"
        >
          Next: {{ nextStepLabel }}
          <i class="bi bi-arrow-right ms-2" />
        </BButton>

        <!-- Final submit button -->
        <div v-else class="d-flex align-items-center gap-3">
          <!-- Direct approval toggle -->
          <div
            v-if="showDirectApproval"
            v-b-tooltip.hover.top="'Skip double review - for experienced curators only'"
            class="direct-approval-toggle"
          >
            <BFormCheckbox v-model="localDirectApproval" switch size="sm">
              Direct approval
            </BFormCheckbox>
          </div>

          <BButton variant="success" :disabled="!isFormValid || isSubmitting" @click="onSubmit">
            <BSpinner v-if="isSubmitting" small class="me-2" />
            <i v-else class="bi bi-check-lg me-2" />
            {{ isSubmitting ? 'Submitting...' : 'Submit Entity' }}
          </BButton>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, computed, ref, watch, type PropType } from 'vue';
import { BButton, BSpinner, BFormCheckbox, vBTooltip } from 'bootstrap-vue-next';
import type { WizardStep } from '@/composables/useEntityForm';

export default defineComponent({
  name: 'FormWizard',

  components: {
    BButton,
    BSpinner,
    BFormCheckbox,
  },

  directives: {
    BTooltip: vBTooltip,
  },

  props: {
    steps: {
      type: Array as PropType<WizardStep[]>,
      required: true,
    },
    stepLabels: {
      type: Object as PropType<Record<WizardStep, string>>,
      required: true,
    },
    currentStepIndex: {
      type: Number,
      required: true,
    },
    isCurrentStepValid: {
      type: Boolean,
      default: true,
    },
    isFormValid: {
      type: Boolean,
      default: true,
    },
    isSubmitting: {
      type: Boolean,
      default: false,
    },
    directApproval: {
      type: Boolean,
      default: false,
    },
    showDirectApproval: {
      type: Boolean,
      default: true,
    },
    showDraftStatus: {
      type: Boolean,
      default: true,
    },
    isSaving: {
      type: Boolean,
      default: false,
    },
    lastSavedFormatted: {
      type: String,
      default: null,
    },
  },

  emits: [
    'update:currentStepIndex',
    'update:directApproval',
    'next',
    'back',
    'submit',
    'go-to-step',
  ],

  setup(props, { emit }) {
    const localDirectApproval = ref(props.directApproval);

    // Sync directApproval with parent
    watch(
      () => props.directApproval,
      (newVal) => {
        localDirectApproval.value = newVal;
      }
    );

    watch(localDirectApproval, (newVal) => {
      emit('update:directApproval', newVal);
    });

    // Computed values
    const totalSteps = computed(() => props.steps.length);

    const currentStep = computed(() => props.steps[props.currentStepIndex]);

    const nextStepLabel = computed(() => {
      if (props.currentStepIndex >= props.steps.length - 1) return '';
      const nextStep = props.steps[props.currentStepIndex + 1];
      return props.stepLabels[nextStep] || '';
    });

    const progressWidth = computed(() => {
      if (props.currentStepIndex === 0) return '0%';
      const percentage = (props.currentStepIndex / (props.steps.length - 1)) * 100;
      return `${percentage}%`;
    });

    const canProceed = computed(() => props.isCurrentStepValid);

    // Navigation handlers
    const onNext = () => {
      if (canProceed.value) {
        emit('next');
      }
    };

    const onBack = () => {
      emit('back');
    };

    const onSubmit = () => {
      if (props.isFormValid) {
        emit('submit');
      }
    };

    const onStepClick = (index: number) => {
      // Only allow clicking on completed steps
      if (index < props.currentStepIndex) {
        emit('go-to-step', index);
      }
    };

    return {
      localDirectApproval,
      totalSteps,
      currentStep,
      nextStepLabel,
      progressWidth,
      canProceed,
      onNext,
      onBack,
      onSubmit,
      onStepClick,
    };
  },
});
</script>

<style scoped>
.form-wizard {
  max-width: 100%;
  margin: 0 auto;
}

/* Progress indicator styles */
.wizard-progress {
  margin-bottom: 0.85rem;
  padding: 0.1rem 0;
}

.wizard-steps {
  position: relative;
  gap: 0.55rem;
}

.wizard-progress-line {
  display: none;
}

.wizard-progress-line-active {
  display: none;
}

.wizard-step {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  align-items: center;
  gap: 0.45rem;
  flex: 1 1 0;
  min-width: 0;
  z-index: 2;
  min-height: 2.35rem;
  padding: 0.35rem 0.5rem;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #fff;
}

.wizard-step.clickable {
  cursor: pointer;
}

.wizard-step.clickable:hover .step-indicator {
  border-color: #0b5cad;
  color: #0b5cad;
}

.wizard-step.active {
  border-color: #9fc1e8;
  background: #eef6ff;
}

.wizard-step.completed {
  border-color: #b7dbc4;
  background: #f0fdf4;
}

.step-indicator {
  width: 1.45rem;
  height: 1.45rem;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 750;
  font-size: 0.78rem;
  background-color: #f8fafc;
  color: #526070;
  border: 1px solid #cbd5e1;
  transition: all 0.3s ease;
}

.wizard-step.active .step-indicator {
  background-color: #0b5cad;
  color: white;
  border-color: #0b5cad;
}

.wizard-step.completed .step-indicator {
  background-color: #15803d;
  color: white;
  border-color: #15803d;
}

.step-label {
  max-width: 100%;
  margin: 0;
  overflow: hidden;
  font-size: 0.75rem;
  color: #526070;
  font-weight: 650;
  line-height: 1.2;
  text-align: left;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.wizard-step.active .step-label {
  color: #0b5cad;
  font-weight: 750;
}

.wizard-step.completed .step-label {
  color: #15803d;
}

/* Content card styles */
.wizard-content {
  min-width: 0;
  margin-bottom: 1rem;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #fff;
}

.wizard-content > * {
  padding: 0.9rem;
}

/* Transition for step content */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

/* Draft status */
.draft-status {
  display: flex;
  align-items: center;
}

/* Direct approval toggle */
.direct-approval-toggle {
  min-height: 2rem;
  padding: 0.25rem 0.65rem;
  background-color: #fffbeb;
  border: 1px solid #f59e0b;
  border-radius: 6px;
}

/* Responsive adjustments */
@media (max-width: 768px) {
  .wizard-progress-line,
  .wizard-progress-line-active {
    display: none;
  }

  .wizard-steps {
    display: grid !important;
    grid-template-columns: repeat(5, minmax(0, 1fr));
    gap: 0.35rem;
  }

  .wizard-step {
    display: flex;
    min-height: 2rem;
    justify-content: center;
    padding: 0.3rem;
  }

  .step-label {
    display: none;
  }

  .wizard-step.active .step-label {
    display: block;
    position: absolute;
    top: 2.05rem;
    left: 0;
    right: 0;
  }
}
</style>
