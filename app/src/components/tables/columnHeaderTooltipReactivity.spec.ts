// Regression guard: faceted-table column-header tooltips must update reactively
// when `count_filtered` changes (i.e. when the user applies/changes a filter).
//
// Root cause of the bug this guards (Entities/Genes/Phenotypes/PubtatorNDDGenes/
// CurationComparisons all showed e.g. "4200/4200" instead of "1997/4200" after an
// interactive filter): bootstrap-vue-next's `v-b-tooltip` directive only re-renders
// its floating popover body when `binding.value` changes — `hasBindingChanged()`
// compares `JSON.stringify([binding.modifiers, binding.value])`. The tables used to
// pass the tooltip text via the reactive `:title` ATTRIBUTE, leaving `binding.value`
// undefined and unchanging, so the popover body was frozen at its first render even
// though `data-original-title` was patched. The fix binds the text through the
// directive VALUE (`v-b-tooltip.hover.bottom="getTooltipText(field)"`).
//
// These tests pin that contract against the REAL bvn directive so a revert to the
// `:title`-attribute form fails CI. See app/src/composables/useColumnTooltip.ts and
// the column-header slots in the faceted table components.

import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import { defineComponent, h, withDirectives, ref, nextTick } from 'vue';
import { vBTooltip } from 'bootstrap-vue-next';
import { useColumnTooltip } from '@/composables/useColumnTooltip';

const { getTooltipText } = useColumnTooltip();

/** Mount a header div using the directive exactly as the tables do. */
function mountHeader(
  mode: 'value' | 'title-attr',
  field: { count: number; count_filtered: number }
) {
  const fieldRef = ref({ key: 'symbol', label: 'Symbol', ...field });
  const Harness = defineComponent({
    setup() {
      return () => {
        const tooltip = getTooltipText(fieldRef.value);
        if (mode === 'value') {
          // Fixed approach: content flows through the directive VALUE → reactive.
          return withDirectives(h('div', {}, 'Symbol'), [
            [vBTooltip, tooltip, '', { hover: true, bottom: true }],
          ]);
        }
        // Buggy approach: content via the :title attribute, directive has no value.
        return withDirectives(h('div', { title: tooltip }, 'Symbol'), [
          [vBTooltip, undefined, '', { hover: true, bottom: true }],
        ]);
      };
    },
  });
  const wrapper = mount(Harness, { attachTo: document.body });
  return { wrapper, fieldRef };
}

async function settle() {
  await nextTick();
  await new Promise((r) => setTimeout(r, 25));
  await nextTick();
}

function popoverBody(): string {
  return document.querySelector('.tooltip-inner')?.textContent?.trim() ?? '';
}

describe('faceted column-header tooltip reactivity (bvn v-b-tooltip)', () => {
  it('value-bound tooltip body updates when count_filtered changes (the fix)', async () => {
    const { wrapper, fieldRef } = mountHeader('value', { count: 4200, count_filtered: 4200 });
    await settle();
    expect(popoverBody()).toBe('Symbol (unique filtered/total values: 4200/4200)');

    // Simulate applying a filter: count_filtered drops, count (total) stays.
    fieldRef.value = { ...fieldRef.value, count_filtered: 1997 };
    await settle();
    expect(popoverBody()).toBe('Symbol (unique filtered/total values: 1997/4200)');

    wrapper.unmount();
  });

  it('title-attribute binding does NOT update the popover body (documents the bug)', async () => {
    const { wrapper, fieldRef } = mountHeader('title-attr', { count: 4200, count_filtered: 4200 });
    await settle();
    expect(popoverBody()).toBe('Symbol (unique filtered/total values: 4200/4200)');

    fieldRef.value = { ...fieldRef.value, count_filtered: 1997 };
    await settle();
    // Frozen at the first-render value — this is exactly the regression we fixed.
    expect(popoverBody()).toBe('Symbol (unique filtered/total values: 4200/4200)');

    wrapper.unmount();
  });
});
