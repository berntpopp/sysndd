/** * components/AppFooter.vue * * @description The footer component of the application. * Includes
partner logos and a disclaimer status indicator. */
<template>
  <!-- The footer component -->
  <div class="footer app-footer">
    <BNavbar
      toggleable="sm"
      type="light"
      variant="light"
      fixed="bottom"
      class="app-footer__bar bg-footer"
      aria-label="Footer navigation"
    >
      <div class="footer-shell">
        <div class="footer-links">
          <!-- Disclaimer indicator (left side) -->
          <div class="disclaimer-indicator d-flex align-items-center">
            <button
              class="disclaimer-indicator__btn"
              :title="disclaimerTooltip"
              aria-label="View usage policy and data privacy disclaimer"
              @click="$emit('show-disclaimer')"
            >
              <i class="bi bi-shield-check" aria-hidden="true" />
              <span class="disclaimer-indicator__label">Policy</span>
            </button>
            <span
              v-if="disclaimerStore.isAcknowledged"
              class="disclaimer-indicator__check"
              :title="'Acknowledged: ' + disclaimerStore.formattedAcknowledgmentDate"
            >
              <i class="bi bi-check-circle-fill" aria-hidden="true" />
            </span>
          </div>
        </div>

        <!-- Phones: a worded toggle, so the header keeps the only hamburger. -->
        <BNavbarToggle
          target="footer-collapse"
          class="app-footer__toggle"
          label="Partners and licence"
        >
          <template #default="{ expanded }">
            Partners<i
              :class="['ms-1', expanded ? 'bi bi-chevron-down' : 'bi bi-chevron-up']"
              aria-hidden="true"
            />
          </template>
        </BNavbarToggle>
      </div>

      <!-- The collapsible part of the navbar -->
      <BCollapse id="footer-collapse" is-nav class="app-footer__collapse">
        <BNavbarNav class="footer-partners">
          <FooterNavItem v-for="item in footerItems" :key="item.id" :item="item" />
        </BNavbarNav>
      </BCollapse>
    </BNavbar>
  </div>
</template>

<script>
import FOOTER_NAV_CONSTANTS from '@/assets/js/constants/footer_nav_constants';
import FooterNavItem from '@/components/small/FooterNavItem.vue';
import { useDisclaimerStore } from '@/stores/disclaimer';

export default {
  name: 'AppFooter',
  components: {
    FooterNavItem,
  },
  emits: ['show-disclaimer'],
  data() {
    return {
      footerItems: FOOTER_NAV_CONSTANTS.NAV_ITEMS,
    };
  },
  computed: {
    disclaimerStore() {
      return useDisclaimerStore();
    },
    disclaimerTooltip() {
      if (this.disclaimerStore.isAcknowledged) {
        return `Usage policy acknowledged on ${this.disclaimerStore.formattedAcknowledgmentDate}. Click to review.`;
      }
      return 'View usage policy and data privacy disclaimer';
    },
  },
};
</script>

<style scoped>
.app-footer__bar {
  min-height: 48px;
  padding: 0.25rem 1rem;
  border-top: 1px solid #d9e1ec;
  background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 -10px 28px rgba(30, 41, 59, 0.08);
  backdrop-filter: blur(12px);
}

.bg-footer {
  background-image: none;
}

.footer-shell {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  justify-content: space-between;
  min-width: 9rem;
}

.footer-links,
.footer-partners {
  display: flex;
  align-items: center;
}

.footer-partners {
  flex: 1 1 auto;
  justify-content: flex-end;
  gap: 0.35rem;
}

.app-footer__collapse {
  flex: 1 1 auto;
}

.disclaimer-indicator {
  gap: 0.25rem;
  flex-shrink: 0;
}

.disclaimer-indicator__btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
  min-height: 32px;
  padding: 0.25rem 0.55rem;
  border: 1px solid #cfd8e3;
  border-radius: 999px;
  background: #fff;
  color: #0d47a1;
  font-size: 0.8rem;
  font-weight: 700;
  cursor: pointer;
  transition:
    background-color 0.15s ease,
    border-color 0.15s ease,
    transform 0.15s ease;
}

.disclaimer-indicator__btn:hover {
  border-color: #9fb3c8;
  background: #eef4ff;
  transform: translateY(-1px);
}

.disclaimer-indicator__btn:focus-visible {
  outline: 2px solid #0d47a1;
  outline-offset: 2px;
}

.disclaimer-indicator__check {
  color: #2e7d32;
  font-size: 0.8rem;
  line-height: 1;
}

:deep(.footer-link .nav-link) {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 34px;
  min-height: 30px;
  padding: 0.12rem 0.38rem;
  border-radius: 8px;
  transition:
    background-color 0.15s ease,
    transform 0.15s ease;
}

:deep(.footer-link .nav-link:hover),
:deep(.footer-link .nav-link:focus-visible) {
  background: #f6f8fb;
  transform: translateY(-1px);
}

:deep(.footer-logo) {
  display: block;
  width: auto;
  max-width: 104px;
  max-height: 26px;
  object-fit: contain;
}

:deep(.footer-logo--icon) {
  max-width: 26px;
}

:deep(.footer-logo--license) {
  max-width: 86px;
}

:deep(.footer-logo--partner) {
  max-width: 96px;
}

@media (prefers-reduced-motion: reduce) {
  .disclaimer-indicator__btn,
  :deep(.footer-link .nav-link) {
    transition: none;
  }

  .disclaimer-indicator__btn:hover,
  :deep(.footer-link .nav-link:hover),
  :deep(.footer-link .nav-link:focus-visible) {
    transform: none;
  }
}

/* Footer toggler: worded pill matching the Policy button (WCAG 1.4.11 border contrast). */
/* No display here: Bootstrap hides the toggler from sm up. */
:deep(.navbar-toggler) {
  min-height: 32px;
  padding: 0.25rem 0.65rem;
  color: #0d47a1;
  font-size: 0.8rem;
  font-weight: 700;
  border: 1px solid #cfd8e3;
  border-radius: 999px;
  background: #fff;

  &:focus {
    box-shadow: 0 0 0 0.2rem rgba(13, 71, 161, 0.16);
    outline: none;
  }

  &:hover {
    border-color: #9fb3c8;
    background-color: #f6f8fb;
  }
}

@media (max-width: 575.98px) {
  .app-footer__bar {
    padding: 0.25rem 0.75rem;
  }

  .footer-shell {
    width: 100%;
  }

  .app-footer__collapse {
    margin-top: 0.3rem;
    padding-top: 0.3rem;
    border-top: 1px solid #edf1f7;
  }

  /* Logos in wrapping rows, not one per line down the screen. */
  .footer-partners {
    flex-direction: row;
    flex-wrap: wrap;
    justify-content: center;
  }
}
</style>
