/** * components/AppFooter.vue * * @description The footer component of the application. * Includes
partner logos and a disclaimer status indicator. */
<template>
  <!-- The footer component -->
  <div class="footer">
    <BNavbar toggleable="sm" type="light" variant="light" fixed="bottom" class="py-0 bg-footer">
      <!-- Disclaimer indicator (left side) -->
      <div class="disclaimer-indicator d-flex align-items-center ms-2">
        <button
          class="disclaimer-indicator__btn"
          :title="disclaimerTooltip"
          aria-label="View usage policy and data privacy disclaimer"
          @click="$emit('show-disclaimer')"
        >
          <i class="bi bi-shield-check" aria-hidden="true" />
        </button>
        <span
          v-if="disclaimerStore.isAcknowledged"
          class="disclaimer-indicator__check"
          :title="'Acknowledged: ' + disclaimerStore.formattedAcknowledgmentDate"
        >
          <i class="bi bi-check-circle-fill" aria-hidden="true" />
        </span>
      </div>

      <!-- The navbar toggle button for smaller screen sizes -->
      <BNavbarToggle target="footer-collapse" />
      <!-- The collapsible part of the navbar -->
      <BCollapse id="footer-collapse" is-nav>
        <!-- The navbar items, distributed evenly across the navbar -->
        <BNavbarNav justified class="flex-grow-1">
          <!-- A component for each item in the footer -->
          <FooterNavItem v-for="(item, index) in footerItems" :key="index.id" :item="item" />
        </BNavbarNav>
      </BCollapse>
    </BNavbar>
  </div>
</template>

<script>
import FOOTER_NAV_CONSTANTS from '@/assets/js/constants/footer_nav_constants';
import { defineAsyncComponent } from 'vue';
import { useDisclaimerStore } from '@/stores/disclaimer';

const FooterNavItem = defineAsyncComponent(() => import('@/components/small/FooterNavItem.vue'));

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
.bg-footer {
  background-image: linear-gradient(
    to top,
    #d5d4d0 0%,
    #d5d4d0 1%,
    #eeeeec 31%,
    #efeeec 75%,
    #e9e9e7 100%
  );
  min-height: 50px;
}

.disclaimer-indicator {
  gap: 0.25rem;
  flex-shrink: 0;
}

.disclaimer-indicator__btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  border: none;
  border-radius: 50%;
  background: transparent;
  color: var(--medical-blue-700, #0d47a1);
  font-size: 1rem;
  cursor: pointer;
  transition: background-color 0.15s ease;
}

.disclaimer-indicator__btn:hover {
  background: rgba(13, 71, 161, 0.1);
}

.disclaimer-indicator__btn:focus-visible {
  outline: 2px solid var(--medical-blue-700, #0d47a1);
  outline-offset: 2px;
}

.disclaimer-indicator__check {
  color: var(--status-success, #2e7d32);
  font-size: 0.8rem;
  line-height: 1;
}

@media (prefers-reduced-motion: reduce) {
  .disclaimer-indicator__btn {
    transition: none;
  }
}

/* Footer navbar toggler - WCAG 1.4.11 Non-text Contrast (3:1 minimum)
 * Using dark color for good visibility against light footer background.
 */
:deep(.navbar-toggler) {
  border: 2px solid rgba(0, 0, 0, 0.5);
  padding: 0.5rem;
  border-radius: 4px;

  &:focus {
    box-shadow: 0 0 0 0.25rem rgba(0, 0, 0, 0.15);
    outline: none;
  }

  &:hover {
    border-color: rgba(0, 0, 0, 0.7);
    background-color: rgba(0, 0, 0, 0.05);
  }
}

/* Ensure dark toggler icon for light navbar */
:deep(.navbar-toggler-icon) {
  background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 30 30'%3e%3cpath stroke='rgba%280, 0, 0, 0.7%29' stroke-linecap='round' stroke-miterlimit='10' stroke-width='2' d='M4 7h22M4 15h22M4 23h22'/%3e%3c/svg%3e");
  width: 1.5em;
  height: 1.5em;
}
</style>
