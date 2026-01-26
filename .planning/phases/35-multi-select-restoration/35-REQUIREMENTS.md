# Phase 35: Multi-Select Restoration - Requirements

**Created:** 2026-01-26
**Status:** Approved

## Overview

Restore multi-select capability for phenotypes (HPO terms) and variations (variant types) in curation forms (Review, ModifyEntity, ApproveReview).

## Requirements

### MSEL-01: Hierarchical Multi-Select for Phenotypes

**Original spec:** Bootstrap-Vue-Next BFormSelect with `multiple` attribute

**Revised spec:** PrimeVue TreeSelect in unstyled mode with Bootstrap PT styling

**Revision rationale:** Research (35-RESEARCH.md) confirmed Bootstrap-Vue-Next BFormSelect cannot display hierarchical trees with expand/collapse - it only supports flat optgroups. HPO phenotypes have 5+ levels of hierarchy (16,000+ terms). PrimeVue TreeSelect was established as the standard replacement in Phase 11 technology stack research (STACK.md lines 45-138).

**Acceptance criteria:**
- User can browse hierarchical phenotype tree with expand/collapse
- User can select multiple phenotypes via checkboxes
- User can search phenotypes by name or HP:ID (e.g., "HP:0001250")
- Selected phenotypes display as chips with X removal button
- Tooltip on hover shows full hierarchy path
- At least 1 phenotype required on form submit

### MSEL-02: Hierarchical Multi-Select for Variations

**Original spec:** Bootstrap-Vue-Next BFormSelect with `multiple` attribute

**Revised spec:** PrimeVue TreeSelect in unstyled mode with Bootstrap PT styling

**Revision rationale:** Same as MSEL-01 - variation types also have hierarchical structure that cannot be displayed with BFormSelect optgroups.

**Acceptance criteria:**
- User can browse hierarchical variation tree with expand/collapse
- User can select multiple variations via checkboxes
- User can search variations by name or identifier
- Selected variations display as chips with X removal button
- Tooltip on hover shows full hierarchy path
- At least 1 variation required on form submit

### MSEL-03: Compound Key Format Support

**Spec:** TreeMultiSelect must handle compound key format used by API

**Context:** The curation views use compound keys like `${modifier_id}-${phenotype_id}` (e.g., "present-HP:0001250") for phenotypes. The tree options returned by the API have `id` fields already in this compound format.

**Acceptance criteria:**
- TreeMultiSelect correctly stores and retrieves compound keys
- v-model binding works with string[] containing compound keys
- Chip removal works correctly with compound keys
- Hierarchy path lookup works with compound keys

### MSEL-04: Visual Consistency

**Spec:** TreeMultiSelect must match Bootstrap styling of existing form elements

**Acceptance criteria:**
- Component uses Bootstrap form-control classes
- Dropdown panel uses Bootstrap dropdown-menu styling
- Checkboxes use Bootstrap form-check-input classes
- No PrimeVue CSS imported (unstyled mode only)
- Chips use Bootstrap badge/tag styling

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-26 | Use PrimeVue TreeSelect instead of BFormSelect | BFormSelect cannot display hierarchical trees, only flat optgroups |
| 2026-01-26 | Use unstyled mode with Bootstrap PT props | Maintain visual consistency with existing Bootstrap-Vue-Next forms |
| 2026-01-26 | Display chips below selector (not inline) | Per user decision in CONTEXT.md - "field grows as needed" |

## References

- 35-CONTEXT.md: User decisions on interface behavior
- 35-RESEARCH.md: Technology research and recommendations
- .planning/research/STACK.md: v7 technology stack decisions (Phase 11)
