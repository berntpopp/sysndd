<!-- src/views/RegisterView.vue -->
<!--
  Register page — audit improvements (5→9 target), brought to parity with LoginView.

  A. NO LABELS (a11y fix — critical):
     Original: every BFormGroup had ONLY a placeholder + below-field description;
     no <label> or label-for.  Placeholders disappear on focus/type, leaving
     the field unlabeled while filling.  Fix: add label + label-for to every
     BFormGroup so the field retains its name when typing.  Descriptions kept
     as hint text below the label.

  B. NO h1 (heading-order fix):
     Original: page title was a BCard header="Register new SysNDD account"
     rendered as a non-heading dark bar — semantically invisible to AT.
     Fix: removed BCard wrapper; replaced with a public-hero shell carrying
     a real route-level <h1>, matching the LoginView / AboutView pattern.

  C. DARK BUTTON VARIANT (consistency fix):
     Original: Reset='outline-dark', Register='dark'.  LoginView uses
     'outline-secondary' / 'primary'.  Fix: aligned to Login token palette
     so auth actions are visually identical across pages.

  D. TERMS ERROR ON FIRST PAINT (interaction-state fix):
     Original: BFormGroup description-less terms field and the touched-gate
     logic wasn't preventing the 'You must accept the terms' message from
     appearing on initial render.  Fix: the :state binding on the checkbox
     uses the same touched-gated pattern as every other field — null (no
     styling) until touched.

  E. DARK HEADER BAR (consistency / decoration fix):
     Removed header-bg-variant='dark' + header-text-variant='white' BCard.
     The page now uses the shared public-page / public-shell / login-shell
     layout language (two-panel: context left, form right) matching LoginView.

  F. LEFT-ALIGN LABEL RHYTHM (spacing/density):
     The centered card layout is replaced with the login-shell grid so
     form labels, inputs, and descriptions align to a single left edge.

  All validation behavior, field names, rules, and API call (signup) are
  preserved unchanged.
-->
<template>
  <div class="login-page register-page">
    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />

    <div v-else class="login-shell">
      <!-- ── Left context panel ─────────────────────────────────── -->
      <section class="login-context" aria-labelledby="register-context-title">
        <div>
          <div class="login-brand">
            <img
              src="/SysNDD_brain-dna-magnifying-glass_dall-e_logo.webp"
              width="52"
              height="52"
              alt="SysNDD Logo"
              class="login-brand__logo"
            />
            <div>
              <p class="login-kicker">SysNDD account</p>
              <h1 id="register-context-title" class="login-title">Apply for access</h1>
            </div>
          </div>
          <p class="login-description">
            SysNDD curation and review workflows are available to credentialed researchers.
            Submit this form to request an account — a curator will review your application.
          </p>
          <ul class="login-feature-list">
            <li>
              <i class="bi bi-globe me-1" aria-hidden="true" />
              Public tables, gene pages, analyses, and documentation remain available without an
              account.
            </li>
            <li>
              <i class="bi bi-shield-check" aria-hidden="true" />
              An institutional email address and ORCID are required to verify your identity.
            </li>
            <li>
              <i class="bi bi-person-check" aria-hidden="true" />
              Already have an account?
              <BLink :to="'/Login'">Sign in here.</BLink>
            </li>
          </ul>
        </div>
      </section>

      <!-- ── Right form panel ───────────────────────────────────── -->
      <section class="login-panel register-panel" aria-labelledby="register-form-title">
        <header class="login-panel__header">
          <p class="login-kicker">Create account</p>
          <h2 id="register-form-title" class="login-title">Register</h2>
          <p class="login-description">All fields are required.</p>
        </header>

        <BOverlay :show="show_overlay" rounded="sm">
          <form class="login-form" @submit.prevent="onSubmit">

            <!-- Username -->
            <BFormGroup
              label="Username"
              label-for="reg-username"
              description="Min 5 characters, max 20"
            >
              <BFormInput
                id="reg-username"
                v-model="user_name"
                autocomplete="username"
                placeholder="Choose a username"
                :state="usernameMeta.touched ? (usernameError ? false : true) : null"
              />
              <BFormInvalidFeedback v-if="usernameError">
                {{ usernameError }}
              </BFormInvalidFeedback>
            </BFormGroup>

            <!-- Email -->
            <BFormGroup
              label="Institutional email"
              label-for="reg-email"
              description="Use your institutional or work email address"
            >
              <BFormInput
                id="reg-email"
                v-model="email"
                type="email"
                autocomplete="email"
                placeholder="mail@your-institution.com"
                :state="emailMeta.touched ? (emailError ? false : true) : null"
              />
              <BFormInvalidFeedback v-if="emailError">
                {{ emailError }}
              </BFormInvalidFeedback>
            </BFormGroup>

            <!-- ORCID -->
            <BFormGroup
              label="ORCID"
              label-for="reg-orcid"
              description="Format: NNNN-NNNN-NNNN-NNNX"
            >
              <BFormInput
                id="reg-orcid"
                v-model="orcid"
                autocomplete="off"
                placeholder="0000-0000-0000-000X"
                :state="orcidMeta.touched ? (orcidError ? false : true) : null"
              />
              <BFormInvalidFeedback v-if="orcidError">
                {{ orcidError }}
              </BFormInvalidFeedback>
            </BFormGroup>

            <!-- First name -->
            <BFormGroup
              label="First name"
              label-for="reg-firstname"
              description="Min 2 characters"
            >
              <BFormInput
                id="reg-firstname"
                v-model="first_name"
                autocomplete="given-name"
                placeholder="First name"
                :state="firstnameMeta.touched ? (firstnameError ? false : true) : null"
              />
              <BFormInvalidFeedback v-if="firstnameError">
                {{ firstnameError }}
              </BFormInvalidFeedback>
            </BFormGroup>

            <!-- Family name -->
            <BFormGroup
              label="Family name"
              label-for="reg-familyname"
              description="Min 2 characters"
            >
              <BFormInput
                id="reg-familyname"
                v-model="family_name"
                autocomplete="family-name"
                placeholder="Family name"
                :state="familynameMeta.touched ? (familynameError ? false : true) : null"
              />
              <BFormInvalidFeedback v-if="familynameError">
                {{ familynameError }}
              </BFormInvalidFeedback>
            </BFormGroup>

            <!-- Research interest -->
            <BFormGroup
              label="Research interest"
              label-for="reg-comment"
              description="Briefly describe why you want to contribute to SysNDD (10–250 chars)"
            >
              <BFormInput
                id="reg-comment"
                v-model="comment"
                placeholder="Your interest in SysNDD curation"
                :state="commentMeta.touched ? (commentError ? false : true) : null"
              />
              <BFormInvalidFeedback v-if="commentError">
                {{ commentError }}
              </BFormInvalidFeedback>
            </BFormGroup>

            <!-- Terms -->
            <BFormGroup>
              <BFormCheckbox
                v-model="terms_agreed"
                value="accepted"
                unchecked-value="not_accepted"
                :state="termsMeta.touched ? (termsError ? false : null) : null"
              >
                I accept the terms of use
              </BFormCheckbox>
              <!--
                d-block required: BFormInvalidFeedback only displays when
                adjacent to an .is-invalid control; for checkboxes we force
                it visible only after the field has been touched.
              -->
              <BFormInvalidFeedback
                v-if="termsError && termsMeta.touched"
                class="d-block"
              >
                {{ termsError }}
              </BFormInvalidFeedback>
            </BFormGroup>

            <!-- Actions — aligned with LoginView button variants -->
            <div class="login-actions">
              <BButton variant="outline-secondary" @click="handleReset()">Reset</BButton>
              <BButton
                :class="{ shake: animated }"
                type="submit"
                variant="primary"
                @click="clickHandler()"
              >
                Register
              </BButton>
            </div>
          </form>

          <template #overlay>
            <div class="text-center">
              <i class="bi bi-clipboard-check fs-1" aria-hidden="true" />
              <p>Request sent. Redirecting…</p>
            </div>
          </template>
        </BOverlay>

        <!-- Links row, mirroring LoginView.login-links -->
        <div class="login-links">
          <div>
            Already have an account?
            <BLink :to="'/Login'">Sign in.</BLink>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>

<script>
import { ref } from 'vue';
import { useHead } from '@unhead/vue';
import { useForm, useField, defineRule } from 'vee-validate';
import { required, min, max, email, regex } from '@vee-validate/rules';
import useToast from '@/composables/useToast';
import { useAuth } from '@/composables/useAuth';
import { signup } from '@/api/auth';

// Define validation rules
defineRule('required', required);
defineRule('min', min);
defineRule('max', max);
defineRule('email', email);
defineRule('regex', regex);
defineRule('is', (value, [target]) => value === target || 'You must accept the terms of use');

export default {
  name: 'RegisterView',
  setup() {
    const { makeToast } = useToast();
    const auth = useAuth();
    useHead({
      title: 'Register',
      meta: [
        {
          name: 'description',
          content: 'The Register view allows to apply for a new SysNDD account.',
        },
      ],
    });

    const { handleSubmit, resetForm: resetVeeForm } = useForm();

    const {
      value: user_name,
      errorMessage: usernameError,
      meta: usernameMeta,
    } = useField('username', 'required|min:5|max:20');

    const {
      value: email,
      errorMessage: emailError,
      meta: emailMeta,
    } = useField('email', 'required|email');

    const {
      value: orcid,
      errorMessage: orcidError,
      meta: orcidMeta,
    } = useField('orcid', (value) => {
      if (!value) return 'ORCID is required';
      const orcidRegex = /^(([0-9]{4})-){3}[0-9]{3}[0-9X]$/;
      if (!orcidRegex.test(value)) return 'Invalid ORCID format (NNNN-NNNN-NNNN-NNNX)';
      return true;
    });

    const {
      value: first_name,
      errorMessage: firstnameError,
      meta: firstnameMeta,
    } = useField('firstname', 'required|min:2|max:50');

    const {
      value: family_name,
      errorMessage: familynameError,
      meta: familynameMeta,
    } = useField('familyname', 'required|min:2|max:50');

    const {
      value: comment,
      errorMessage: commentError,
      meta: commentMeta,
    } = useField('comment', 'required|min:10|max:250');

    const {
      value: terms_agreed,
      errorMessage: termsError,
      meta: termsMeta,
    } = useField('terms', (value) => {
      if (value !== 'accepted') return 'You must accept the terms of use';
      return true;
    });

    // Initialize terms_agreed to unchecked
    terms_agreed.value = 'not_accepted';

    const animated = ref(false);
    const show_overlay = ref(false);
    const loading = ref(true);

    return {
      user_name,
      usernameError,
      usernameMeta,
      email,
      emailError,
      emailMeta,
      orcid,
      orcidError,
      orcidMeta,
      first_name,
      firstnameError,
      firstnameMeta,
      family_name,
      familynameError,
      familynameMeta,
      comment,
      commentError,
      commentMeta,
      terms_agreed,
      termsError,
      termsMeta,
      animated,
      show_overlay,
      loading,
      handleSubmit,
      resetVeeForm,
      makeToast,
      auth,
    };
  },

  mounted() {
    // v11.0 closeout F2b: clear any stale session before showing the form.
    if (this.auth.isAuthenticated.value) {
      this.doUserLogOut();
    }
    this.loading = false;
  },

  methods: {
    onSubmit() {
      this.handleSubmit(() => {
        this.sendRegistration();
      })();
    },

    async sendRegistration() {
      const registration_form = {
        user_name: this.user_name,
        email: this.email,
        orcid: this.orcid,
        first_name: this.first_name,
        family_name: this.family_name,
        comment: this.comment,
        terms_agreed: this.terms_agreed,
      };

      try {
        await signup(registration_form);
        this.makeToast('Your registration request has been sent.', 'Success', 'success');
        this.successfulRegistration();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },

    successfulRegistration() {
      this.show_overlay = true;
      setTimeout(() => {
        this.$router.push('/');
      }, 2000);
    },

    handleReset() {
      this.user_name = '';
      this.email = '';
      this.orcid = '';
      this.first_name = '';
      this.family_name = '';
      this.comment = '';
      this.terms_agreed = 'not_accepted';
      this.resetVeeForm();
    },

    clickHandler() {
      this.animated = true;
      setTimeout(() => {
        this.animated = false;
      }, 1000);
    },

    doUserLogOut() {
      if (this.auth.isAuthenticated.value) {
        this.auth.logout();
        this.$router.push('/');
      }
    },
  },
};
</script>

<!-- Shake animation: same as LoginView for consistent auth-form behavior -->
<style scoped>
/* Register-specific form panel — slightly wider than login (more fields) */
.register-panel {
  align-self: start;
}

.shake {
  animation: shake 0.82s cubic-bezier(0.36, 0.07, 0.19, 0.97) both;
  transform: translate3d(0, 0, 0);
}

@keyframes shake {
  10%,
  90% {
    transform: translate3d(-1px, 0, 0);
  }
  20%,
  80% {
    transform: translate3d(2px, 0, 0);
  }
  30%,
  50%,
  70% {
    transform: translate3d(-4px, 0, 0);
  }
  40%,
  60% {
    transform: translate3d(4px, 0, 0);
  }
}

@media (prefers-reduced-motion: reduce) {
  .shake {
    animation: none;
    transform: none;
  }
}
</style>
