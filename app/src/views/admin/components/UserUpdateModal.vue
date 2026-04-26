<!-- app/src/views/admin/components/UserUpdateModal.vue -->
<!-- Edit-user form modal lifted from ManageUser.vue, with vee-validate scoped here. -->
<template>
  <BModal
    :id="modalId"
    v-model="proxyVisible"
    size="lg"
    header-bg-variant="primary"
    header-text-variant="light"
    ok-title="Save Changes"
    ok-variant="primary"
    cancel-title="Cancel"
    cancel-variant="outline-secondary"
    @ok.prevent="onSubmit"
  >
    <template #title>
      <i class="bi bi-person-gear me-2" />
      Edit User: {{ local.user_name }}
    </template>
    <form @submit.prevent="onSubmit">
      <!-- Account Information Section -->
      <div class="mb-4">
        <h6 class="text-muted border-bottom pb-2 mb-3">
          <i class="bi bi-person-badge me-2" />Account Information
        </h6>
        <BRow>
          <BCol md="6">
            <BFormGroup label="Username" label-for="input-user_name" class="mb-3">
              <BInputGroup>
                <template #prepend>
                  <BInputGroupText><i class="bi bi-at" /></BInputGroupText>
                </template>
                <BFormInput
                  id="input-user_name"
                  v-model="local.user_name"
                  type="text"
                  placeholder="Enter username"
                  :state="userNameMeta.touched ? (userNameError ? false : true) : null"
                />
              </BInputGroup>
              <BFormInvalidFeedback v-if="userNameError" :state="false">
                {{ userNameError }}
              </BFormInvalidFeedback>
            </BFormGroup>
          </BCol>
          <BCol md="6">
            <BFormGroup label="Email" label-for="input-email" class="mb-3">
              <BInputGroup>
                <template #prepend>
                  <BInputGroupText><i class="bi bi-envelope" /></BInputGroupText>
                </template>
                <BFormInput
                  id="input-email"
                  v-model="local.email"
                  type="email"
                  placeholder="user@example.com"
                  :state="emailMeta.touched ? (emailError ? false : true) : null"
                />
              </BInputGroup>
              <BFormInvalidFeedback v-if="emailError" :state="false">
                {{ emailError }}
              </BFormInvalidFeedback>
            </BFormGroup>
          </BCol>
        </BRow>
        <BRow>
          <BCol md="6">
            <BFormGroup label="Abbreviation" label-for="input-abbreviation" class="mb-3">
              <BInputGroup>
                <template #prepend>
                  <BInputGroupText><i class="bi bi-hash" /></BInputGroupText>
                </template>
                <BFormInput
                  id="input-abbreviation"
                  v-model="local.abbreviation"
                  type="text"
                  placeholder="XX"
                  maxlength="5"
                  :state="abbreviationMeta.touched ? (abbreviationError ? false : true) : null"
                />
              </BInputGroup>
              <BFormInvalidFeedback v-if="abbreviationError" :state="false">
                {{ abbreviationError }}
              </BFormInvalidFeedback>
            </BFormGroup>
          </BCol>
          <BCol md="6">
            <BFormGroup label="ORCID" label-for="input-orcid" class="mb-3">
              <BInputGroup>
                <template #prepend>
                  <BInputGroupText><i class="bi bi-link-45deg" /></BInputGroupText>
                </template>
                <BFormInput
                  id="input-orcid"
                  v-model="local.orcid"
                  type="text"
                  placeholder="0000-0000-0000-0000"
                  :state="orcidMeta.touched ? (orcidError ? false : true) : null"
                />
              </BInputGroup>
              <BFormInvalidFeedback v-if="orcidError" :state="false">
                {{ orcidError }}
              </BFormInvalidFeedback>
            </BFormGroup>
          </BCol>
        </BRow>
      </div>

      <!-- Personal Information Section -->
      <div class="mb-4">
        <h6 class="text-muted border-bottom pb-2 mb-3">
          <i class="bi bi-person me-2" />Personal Information
        </h6>
        <BRow>
          <BCol md="6">
            <BFormGroup label="First Name" label-for="input-first_name" class="mb-3">
              <BFormInput
                id="input-first_name"
                v-model="local.first_name"
                type="text"
                placeholder="First name"
                :state="firstNameMeta.touched ? (firstNameError ? false : true) : null"
              />
              <BFormInvalidFeedback v-if="firstNameError">
                {{ firstNameError }}
              </BFormInvalidFeedback>
            </BFormGroup>
          </BCol>
          <BCol md="6">
            <BFormGroup label="Family Name" label-for="input-family_name" class="mb-3">
              <BFormInput
                id="input-family_name"
                v-model="local.family_name"
                type="text"
                placeholder="Family name"
                :state="familyNameMeta.touched ? (familyNameError ? false : true) : null"
              />
              <BFormInvalidFeedback v-if="familyNameError">
                {{ familyNameError }}
              </BFormInvalidFeedback>
            </BFormGroup>
          </BCol>
        </BRow>
      </div>

      <!-- Role & Status Section -->
      <div class="mb-3">
        <h6 class="text-muted border-bottom pb-2 mb-3">
          <i class="bi bi-shield-check me-2" />Role &amp; Status
        </h6>
        <BRow>
          <BCol md="6">
            <BFormGroup label="Role" label-for="input-user_role" class="mb-3">
              <BFormSelect
                id="input-user_role"
                v-model="local.user_role"
                :options="roleSelectOptions"
                :state="userRoleMeta.touched ? (userRoleError ? false : true) : null"
              />
              <BFormInvalidFeedback v-if="userRoleError">
                {{ userRoleError }}
              </BFormInvalidFeedback>
            </BFormGroup>
          </BCol>
          <BCol md="6">
            <BFormGroup label="Account Status" label-for="input-approved" class="mb-3">
              <div class="d-flex flex-column gap-2">
                <!-- Current status display -->
                <div class="d-flex align-items-center">
                  <span class="text-muted me-2">Current:</span>
                  <span
                    class="badge"
                    :class="local.approved ? 'bg-success' : 'bg-warning text-dark'"
                  >
                    <i
                      :class="
                        local.approved ? 'bi bi-check-circle-fill' : 'bi bi-clock-fill'
                      "
                      class="me-1"
                    />
                    {{ local.approved ? 'Approved' : 'Pending' }}
                  </span>
                </div>
                <!-- Toggle buttons -->
                <BButtonGroup size="sm">
                  <BButton
                    :variant="local.approved ? 'success' : 'outline-success'"
                    @click="local.approved = true"
                  >
                    <i class="bi bi-check-lg me-1" />
                    Approve
                  </BButton>
                  <BButton
                    :variant="!local.approved ? 'warning' : 'outline-warning'"
                    @click="local.approved = false"
                  >
                    <i class="bi bi-clock me-1" />
                    Set Pending
                  </BButton>
                </BButtonGroup>
                <small class="text-muted">
                  {{
                    local.approved
                      ? 'User can access the system.'
                      : 'User cannot log in until approved.'
                  }}
                </small>
              </div>
            </BFormGroup>
          </BCol>
        </BRow>
        <BRow>
          <BCol>
            <BFormGroup label="Comment" label-for="input-comment" class="mb-0">
              <BFormTextarea
                id="input-comment"
                v-model="local.comment"
                placeholder="Add notes about this user..."
                rows="2"
              />
            </BFormGroup>
          </BCol>
        </BRow>
      </div>

      <!-- Password Reset Section -->
      <UserPasswordChangeForm
        v-model="passwordChangeProxy"
        :validation="passwordValidation"
        :is-changing="isChangingPassword"
        @submit="$emit('change-password')"
        @generate="$emit('generate-password')"
      />
    </form>
  </BModal>
</template>

<script lang="ts">
import { computed, defineComponent, ref, watch, type PropType } from 'vue';
import { useField, useForm, defineRule } from 'vee-validate';
import { required, min, max, email } from '@vee-validate/rules';
import UserPasswordChangeForm from './UserPasswordChangeForm.vue';

defineRule('required', required);
defineRule('min', min);
defineRule('max', max);
defineRule('email', email);

interface UserSummary {
  user_id: number;
  user_name: string;
  email: string;
  orcid?: string;
  abbreviation: string;
  first_name: string;
  family_name: string;
  user_role: string;
  approved: number | boolean;
  comment?: string;
}

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
  name: 'UserUpdateModal',
  components: { UserPasswordChangeForm },
  props: {
    visible: { type: Boolean, default: false },
    user: { type: Object as PropType<Partial<UserSummary> | null>, default: null },
    roleOptions: {
      type: Array as PropType<Array<{ value: string; text: string }>>,
      default: () => [],
    },
    passwordChange: {
      type: Object as PropType<PasswordChangeModel>,
      required: true,
    },
    passwordValidation: {
      type: Object as PropType<PasswordValidation>,
      required: true,
    },
    isChangingPassword: { type: Boolean, default: false },
  },
  emits: ['update:visible', 'submit', 'cancel', 'change-password', 'generate-password', 'update:password-change'],
  setup(props, { emit }) {
    const modalId = 'update-usermodal';

    const proxyVisible = computed({
      get: () => props.visible,
      set: (v) => emit('update:visible', v),
    });

    // Two-way proxy for passwordChange so UserPasswordChangeForm can v-model it
    const passwordChangeProxy = computed({
      get: () => props.passwordChange,
      set: (v) => emit('update:password-change', v),
    });

    const { handleSubmit, setValues } = useForm();

    const {
      value: _userName,
      errorMessage: userNameError,
      meta: userNameMeta,
    } = useField('user_name', 'required|min:2|max:50');

    const {
      value: _userEmail,
      errorMessage: emailError,
      meta: emailMeta,
    } = useField('email', 'required|email');

    const { value: _orcid, errorMessage: orcidError, meta: orcidMeta } = useField('orcid');

    const {
      value: _abbreviation,
      errorMessage: abbreviationError,
      meta: abbreviationMeta,
    } = useField('abbreviation', 'required');

    const {
      value: _firstName,
      errorMessage: firstNameError,
      meta: firstNameMeta,
    } = useField('first_name', 'required|min:2|max:50');

    const {
      value: _familyName,
      errorMessage: familyNameError,
      meta: familyNameMeta,
    } = useField('family_name', 'required|min:2|max:50');

    const {
      value: _userRole,
      errorMessage: userRoleError,
      meta: userRoleMeta,
    } = useField('user_role', 'required');

    const local = ref<Partial<UserSummary>>({});

    const roleSelectOptions = computed(() => [
      { value: 'Administrator', text: 'Administrator' },
      { value: 'Curator', text: 'Curator' },
      { value: 'Reviewer', text: 'Reviewer' },
      { value: 'Viewer', text: 'Viewer' },
    ]);

    watch(
      () => props.user,
      (next) => {
        if (next) {
          local.value = { ...next };
          setValues({
            user_name: next.user_name ?? '',
            email: next.email ?? '',
            orcid: next.orcid ?? '',
            abbreviation: next.abbreviation ?? '',
            first_name: next.first_name ?? '',
            family_name: next.family_name ?? '',
            user_role: next.user_role ?? '',
          });
        }
      },
      { immediate: true },
    );

    function onSubmit(): void {
      handleSubmit(() => emit('submit', { ...local.value }))();
    }

    return {
      modalId,
      proxyVisible,
      passwordChangeProxy,
      local,
      roleSelectOptions,
      onSubmit,
      userNameError,
      userNameMeta,
      emailError,
      emailMeta,
      orcidError,
      orcidMeta,
      abbreviationError,
      abbreviationMeta,
      firstNameError,
      firstNameMeta,
      familyNameError,
      familyNameMeta,
      userRoleError,
      userRoleMeta,
    };
  },
});
</script>
