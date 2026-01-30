<template>
  <div class="form-wizard">
    <!-- Progress Indicator -->
    <div class="wizard-progress mb-4">
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
    <BCard class="wizard-content mb-4" body-class="p-4">
      <div class="step-header mb-4">
        <h5 class="mb-1">{{ stepLabels[currentStep] }}</h5>
        <small class="text-muted">Step {{ currentStepIndex + 1 }} of {{ totalSteps }}</small>
      </div>

      <!-- Dynamic step content -->
      <transition name="fade" mode="out-in">
        <div :key="currentStep">
          <slot :name="currentStep" />
        </div>
      </transition>
    </BCard>

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
import { BCard, BButton, BSpinner, BFormCheckbox, vBTooltip } from 'bootstrap-vue-next';
import type { WizardStep } from '@/composables/useEntityForm';

export default defineComponent({
  name: 'FormWizard',

  components: {
    BCard,
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
  max-width: 900px;
  margin: 0 auto;
}

/* Progress indicator styles */
.wizard-progress {
  padding: 0 1rem;
}

.wizard-steps {
  position: relative;
}

.wizard-progress-line {
  position: absolute;
  top: 20px;
  left: 40px;
  right: 40px;
  height: 3px;
  background-color: #e9ecef;
  z-index: 0;
}

.wizard-progress-line-active {
  position: absolute;
  top: 20px;
  left: 40px;
  height: 3px;
  background-color: #0d6efd;
  z-index: 1;
  transition: width 0.3s ease;
}

.wizard-step {
  display: flex;
  flex-direction: column;
  align-items: center;
  z-index: 2;
  background: white;
  padding: 0 0.5rem;
}

.wizard-step.clickable {
  cursor: pointer;
}

.wizard-step.clickable:hover .step-indicator {
  transform: scale(1.1);
}

.step-indicator {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 1rem;
  background-color: #e9ecef;
  color: #6c757d;
  border: 3px solid #e9ecef;
  transition: all 0.3s ease;
}

.wizard-step.active .step-indicator {
  background-color: #0d6efd;
  color: white;
  border-color: #0d6efd;
}

.wizard-step.completed .step-indicator {
  background-color: #198754;
  color: white;
  border-color: #198754;
}

.step-label {
  margin-top: 0.5rem;
  font-size: 0.75rem;
  color: #6c757d;
  text-align: center;
  white-space: nowrap;
}

.wizard-step.active .step-label {
  color: #0d6efd;
  font-weight: 600;
}

.wizard-step.completed .step-label {
  color: #198754;
}

/* Content card styles */
.wizard-content {
  border-radius: 0.5rem;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}

.step-header {
  border-bottom: 1px solid #e9ecef;
  padding-bottom: 1rem;
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
  padding: 0.25rem 0.75rem;
  background-color: #fff3cd;
  border: 1px solid #ffc107;
  border-radius: 0.375rem;
}

/* Responsive adjustments */
@media (max-width: 768px) {
  .wizard-progress-line,
  .wizard-progress-line-active {
    display: none;
  }

  .wizard-steps {
    flex-wrap: wrap;
    gap: 0.5rem;
  }

  .step-label {
    display: none;
  }

  .wizard-step.active .step-label {
    display: block;
  }
}
</style>
