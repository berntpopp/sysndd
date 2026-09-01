import type { BootstrapVueOptions } from 'bootstrap-vue-next';

/**
 * Global Bootstrap-Vue-Next component defaults.
 *
 * `BFormCheckbox.uncheckedValue` defaulted to `false` up to and including
 * bootstrap-vue-next 0.45.x. Release 0.46.0 changed that default to `null`
 * ("change BFormCheckbox uncheckedValue default from false to null").
 *
 * SysNDD binds ~40 checkboxes and switches straight into typed API payloads —
 * `direct_approval` and `clear_old` are declared `boolean | string`, and
 * `problematic` is `number | string` — so an unchecked switch emitting `null`
 * would silently drop the field from the query string (axios omits `null`
 * params) or send a JSON `null` where the Plumber handler expects `FALSE`/`0`.
 * Restoring the historical default keeps every existing binding truthful
 * instead of patching each call site with `:unchecked-value="false"`.
 *
 * @see https://github.com/bootstrap-vue-next/bootstrap-vue-next/commit/d208f60422a0c01e2bb3bbfdf3aaeb0243ba8fb2
 */
export const bootstrapVueNextOptions: BootstrapVueOptions = {
  components: {
    BFormCheckbox: { uncheckedValue: false },
  },
};

export default bootstrapVueNextOptions;
