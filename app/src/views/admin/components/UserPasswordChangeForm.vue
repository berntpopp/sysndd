<!-- app/src/views/admin/components/UserPasswordChangeForm.vue -->
<!-- Password-reset panel lifted from the update-modal template. -->
<template>
  <div class="mb-3">
    <h6 class="text-muted border-bottom pb-2 mb-3"><i class="bi bi-key me-2" />Password Reset</h6>
    <BAlert variant="info" :model-value="true" class="mb-3">
      <i class="bi bi-info-circle me-2" />
      As an administrator, you can set a new password for this user. Password requirements: 8+
      characters, uppercase, lowercase, number, and special character (!@#$%^&*).
    </BAlert>
    <BRow>
      <BCol md="6">
        <BFormGroup label="New Password" label-for="input-new-password" class="mb-3">
          <BInputGroup>
            <template #prepend>
              <BInputGroupText><i class="bi bi-lock" /></BInputGroupText>
            </template>
            <BFormInput
              id="input-new-password"
              :value="modelValue.newPassword"
              :type="modelValue.showPassword ? 'text' : 'password'"
              placeholder="Enter new password"
              :state="validation.isValid"
              autocomplete="new-password"
              @input="emitInput('newPassword', $event)"
            />
            <template #append>
              <BButton variant="outline-secondary" @click="toggleShowPassword">
                <i :class="modelValue.showPassword ? 'bi bi-eye-slash' : 'bi bi-eye'" />
              </BButton>
            </template>
          </BInputGroup>
          <div v-if="modelValue.newPassword" class="mt-2">
            <small
              v-for="(rule, key) in validation.rules"
              :key="key"
              class="d-block"
              :class="rule.valid ? 'text-success' : 'text-danger'"
            >
              <i :class="rule.valid ? 'bi bi-check-circle' : 'bi bi-x-circle'" class="me-1" />
              {{ rule.label }}
            </small>
          </div>
        </BFormGroup>
      </BCol>
      <BCol md="6">
        <BFormGroup label="Confirm Password" label-for="input-confirm-password" class="mb-3">
          <BInputGroup>
            <template #prepend>
              <BInputGroupText><i class="bi bi-lock-fill" /></BInputGroupText>
            </template>
            <BFormInput
              id="input-confirm-password"
              :value="modelValue.confirmPassword"
              :type="modelValue.showPassword ? 'text' : 'password'"
              placeholder="Confirm new password"
              :state="
                modelValue.confirmPassword
                  ? modelValue.newPassword === modelValue.confirmPassword
                  : null
              "
              autocomplete="new-password"
              @input="emitInput('confirmPassword', $event)"
            />
          </BInputGroup>
          <BFormInvalidFeedback
            v-if="
              modelValue.confirmPassword && modelValue.newPassword !== modelValue.confirmPassword
            "
            :state="false"
          >
            Passwords do not match
          </BFormInvalidFeedback>
        </BFormGroup>
      </BCol>
    </BRow>
    <BRow>
      <BCol class="d-flex justify-content-between">
        <BButton variant="outline-secondary" @click="$emit('generate')">
          <i class="bi bi-shuffle me-1" />
          Generate Password
        </BButton>
        <BButton
          variant="warning"
          :disabled="
            !validation.isValid ||
            modelValue.newPassword !== modelValue.confirmPassword ||
            isChanging
          "
          @click="$emit('submit')"
        >
          <BSpinner v-if="isChanging" small class="me-1" />
          <i v-else class="bi bi-key-fill me-1" />
          {{ isChanging ? 'Changing...' : 'Change Password' }}
        </BButton>
      </BCol>
    </BRow>
  </div>
</template>

<script lang="ts">
import { defineComponent, type PropType } from 'vue';

interface PasswordChangeModel {
  newPassword: string;
  confirmPassword: string;
  showPassword: boolean;
}

interface PasswordRule {
  label: string;
  valid: boolean;
}

interface PasswordValidation {
  isValid: boolean | null;
  rules: Record<string, PasswordRule>;
}

export default defineComponent({
  name: 'UserPasswordChangeForm',
  props: {
    modelValue: {
      type: Object as PropType<PasswordChangeModel>,
      required: true,
    },
    validation: {
      type: Object as PropType<PasswordValidation>,
      required: true,
    },
    isChanging: { type: Boolean, default: false },
  },
  emits: ['update:modelValue', 'submit', 'generate'],
  setup(props, { emit }) {
    function emitInput(field: 'newPassword' | 'confirmPassword', event: Event): void {
      const target = event.target as HTMLInputElement;
      emit('update:modelValue', { ...props.modelValue, [field]: target.value });
    }
    function toggleShowPassword(): void {
      emit('update:modelValue', {
        ...props.modelValue,
        showPassword: !props.modelValue.showPassword,
      });
    }
    return { emitInput, toggleShowPassword };
  },
});
</script>
