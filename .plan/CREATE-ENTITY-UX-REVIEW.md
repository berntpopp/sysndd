# CreateEntity Page UI/UX Review & Improvement Plan

**Date:** 2025-01-24
**Reviewer:** Senior UI/UX Specialist
**Page:** `/CreateEntity`
**Target User:** Genetic disease curators entering new gene-disease relationships

---

## Executive Summary

The CreateEntity page serves a critical function: enabling expert curators to enter new gene-disease entity data into the SysNDD database. While functional, the current design has significant UX issues that increase cognitive load, reduce data quality, and slow down the curation workflow.

### Overall Rating: 5.5/10

| Category | Score | Notes |
|----------|-------|-------|
| Visual Design | 5/10 | Flat, monotone, lacks visual hierarchy |
| Information Architecture | 4/10 | No logical grouping, all fields in single column |
| Form Flow | 4/10 | No progress indication, no step guidance |
| Data Entry Efficiency | 6/10 | Autocompletes help, but no smart defaults |
| Error Prevention | 3/10 | No inline validation, no field-level help |
| Accessibility | 5/10 | Labels exist but lack descriptions |
| Expert User Support | 6/10 | Some shortcuts, but no bulk entry mode |

---

## Current State Analysis

### What Works

1. **Autocomplete for Gene/Disease** - Reduces manual entry errors
2. **Placeholder text** - Provides input format hints
3. **Logical field order** - Gene → Disease → Inheritance follows mental model
4. **Tag input for PMIDs** - Good pattern for multiple values

### Critical Issues

#### 1. No Progress Indication or Step Guidance
- All 12+ fields shown at once creates overwhelming first impression
- No visual indication of which fields are required vs optional
- No sense of progress as user completes form
- **Research finding:** [81% of users abandon forms that feel overwhelming](https://buildform.ai/blog/form-design-best-practices/)

#### 2. Poor Visual Hierarchy
- All labels have same visual weight
- Submit button at TOP (unconventional, easy to miss after filling form)
- Horizontal dividers don't create meaningful sections
- Center-aligned labels harder to scan than left-aligned

#### 3. No Field-Level Validation or Help
- No real-time validation feedback
- No tooltip/help text explaining what each field expects
- Status dropdown requires curator to understand classification criteria
- **Research finding:** [31% of sites lack inline validation](https://www.smashingmagazine.com/2022/09/inline-validation-web-forms-ux/)

#### 4. Poor Grouping of Related Fields
- Entity Core (Gene, Disease, Inheritance) not visually grouped
- Clinical Evidence (Publications, Synopsis) not grouped
- Phenotype data scattered

#### 5. Missing Curator Workflow Support
- No draft/save functionality for complex entries
- No way to duplicate from existing entity
- No quick-add mode for experienced curators
- No preview before submission

#### 6. Submission Flow Issues
- Submit button at TOP instead of bottom
- No confirmation of what will be submitted
- "Direct approval" checkbox buried in modal
- No clear indication of what happens after submission

---

## Research-Based Recommendations

### Multi-Step Wizard Pattern

Based on [Nielsen Norman Group wizard guidelines](https://www.nngroup.com/articles/wizards/) and [PatternFly wizard design](https://www.patternfly.org/components/wizard/design-guidelines/), complex data entry tasks benefit from step-by-step guidance.

**Proposed Steps:**
1. **Core Identity** - Gene, Disease, Inheritance, NDD status
2. **Clinical Evidence** - Publications, GeneReviews, Synopsis
3. **Phenotype & Variation** - Phenotypes, Variation ontology
4. **Classification** - Status, Comments
5. **Review & Submit** - Preview all data before submission

### ClinGen-Inspired Workflow

The [ClinGen Gene Curation Interface](https://clinicalgenome.org/tools/educational-resources/gene-disease-validity-topics/gene-curation-interface/) uses a structured workflow that:
- Links OMIM and Mondo identifiers automatically
- Provides precuration data following FAIR principles
- Uses standard ontologies (HPO, Mondo, OMIM)
- Tracks curation status through defined stages

### Form Design Best Practices

From [UX Design Institute](https://www.uxdesigninstitute.com/blog/guide-to-form-design-with-tips/) and [Interaction Design Foundation](https://www.interaction-design.org/literature/article/ui-form-design):
- One-column layout for better scanning
- Labels above fields, left-aligned
- Required fields clearly marked
- Error messages near relevant fields
- Progress indicator for multi-step forms

---

## Detailed Improvement Plan

### Phase 1: Quick Wins (Low Effort, High Impact)

#### 1.1 Move Submit Button to Bottom
```
Current: [Submit] at top
Improved: [Submit] at bottom after all fields
```

#### 1.2 Add Required Field Indicators
- Add asterisk (*) to required field labels
- Add "Required" text to form header
- Style: `<span class="text-danger">*</span>`

#### 1.3 Add Field Help Text
Add `<small class="text-muted">` descriptions below each field:
- **Gene:** "Select HGNC gene symbol associated with this disease"
- **Disease:** "Select OMIM or Mondo disease identifier"
- **Status:** "Evidence strength: Definitive (3+ unrelated cases), Moderate (2 cases), Limited (1 case)"
- **Synopsis:** "Brief clinical summary (10-2000 characters)"

#### 1.4 Improve Visual Grouping
Use Bootstrap cards to group related fields:
```html
<BCard header="Core Entity">
  Gene, Disease, Inheritance, NDD
</BCard>
<BCard header="Evidence">
  Publications, GeneReviews, Synopsis
</BCard>
<BCard header="Phenotype & Variation">
  Phenotypes, Variation ontology
</BCard>
<BCard header="Classification">
  Status, Comments
</BCard>
```

#### 1.5 Left-Align Labels
Change from `text-center` to `text-start` for all labels

---

### Phase 2: Form Validation & Feedback

#### 2.1 Inline Validation
Implement "reward early, punish late" pattern from [Smashing Magazine](https://www.smashingmagazine.com/2022/09/inline-validation-web-forms-ux/):
- Validate on blur (after user leaves field)
- Show success checkmark when valid
- Show error only after user has made an error

#### 2.2 Real-Time Character Count for Synopsis
```vue
<BFormTextarea v-model="synopsis">
<small>{{ synopsis.length }}/2000 characters</small>
```

#### 2.3 PMID Validation with Preview
- Validate PMID format on entry
- Fetch and display publication title from PubMed API
- Show error if PMID doesn't exist

#### 2.4 Gene-Disease Relationship Check
- When both Gene and Disease are selected, check if entity already exists
- Show warning: "Similar entity exists: [link]"

---

### Phase 3: Multi-Step Wizard (Major Enhancement)

#### 3.1 Wizard Structure

```
┌─────────────────────────────────────────────────────────┐
│  Step 1      Step 2       Step 3      Step 4    Step 5  │
│  ● ───────── ○ ───────── ○ ───────── ○ ───────── ○      │
│  Core       Evidence    Phenotype   Status     Review   │
│  Identity                                               │
└─────────────────────────────────────────────────────────┘
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │                                                 │   │
│  │   Gene    [MECP2 autocomplete         ]        │   │
│  │                                                 │   │
│  │   Disease [Rett syndrome autocomplete ]        │   │
│  │                                                 │   │
│  │   Inheritance [Select inheritance... v]        │   │
│  │                                                 │   │
│  │   NDD phenotype  ○ Yes  ○ No                   │   │
│  │                                                 │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│                        [Back]  [Next: Evidence →]       │
└─────────────────────────────────────────────────────────┘
```

#### 3.2 Step Definitions

**Step 1: Core Identity**
- Gene (required)
- Disease (required)
- Inheritance (required)
- NDD phenotype (required)
- Validation: All 4 fields must be filled

**Step 2: Evidence**
- Publications (required, at least 1 PMID)
- GeneReviews (optional)
- Synopsis (required, 10-2000 chars)
- Validation: At least 1 publication, synopsis filled

**Step 3: Phenotype & Variation**
- Phenotypes (optional, multi-select)
- Variation ontology (optional, multi-select)
- Validation: None required, can skip

**Step 4: Classification**
- Status (required)
- Comments (optional)
- Validation: Status selected

**Step 5: Review & Submit**
- Display all entered data in read-only format
- Edit buttons to jump back to specific steps
- Direct approval checkbox (with tooltip warning)
- Submit button

#### 3.3 Implementation with Bootstrap-Vue-Next

```vue
<template>
  <BCard>
    <!-- Progress Indicator -->
    <div class="wizard-steps mb-4">
      <div
        v-for="(step, index) in steps"
        :key="index"
        :class="['step', { active: currentStep === index, completed: currentStep > index }]"
      >
        <span class="step-number">{{ index + 1 }}</span>
        <span class="step-label">{{ step.label }}</span>
      </div>
    </div>

    <!-- Step Content -->
    <component :is="steps[currentStep].component" v-model="formData" />

    <!-- Navigation -->
    <div class="d-flex justify-content-between mt-4">
      <BButton
        v-if="currentStep > 0"
        variant="outline-secondary"
        @click="currentStep--"
      >
        ← Back
      </BButton>
      <BButton
        v-if="currentStep < steps.length - 1"
        variant="primary"
        :disabled="!isStepValid"
        @click="currentStep++"
      >
        Next: {{ steps[currentStep + 1].label }} →
      </BButton>
      <BButton
        v-if="currentStep === steps.length - 1"
        variant="success"
        @click="submitEntity"
      >
        Submit Entity
      </BButton>
    </div>
  </BCard>
</template>
```

---

### Phase 4: Expert User Features

#### 4.1 Quick Entry Mode Toggle
For experienced curators who know the form:
- Single-page view (current layout, improved)
- Keyboard shortcuts for common actions
- Tab order optimized for speed

#### 4.2 Draft/Auto-Save
- Auto-save to localStorage every 30 seconds
- "Resume draft" prompt on page load
- Clear draft after successful submission

#### 4.3 Batch Entry Mode
- CSV/TSV import for multiple entities
- Template download
- Validation before import

---

### Phase 5: Accessibility Improvements

#### 5.1 ARIA Labels
```html
<BFormInput
  id="gene-select"
  aria-describedby="gene-help"
  aria-required="true"
/>
<small id="gene-help">Select HGNC gene symbol</small>
```

#### 5.2 Error Announcements
```html
<div aria-live="polite" class="sr-only">
  {{ validationMessage }}
</div>
```

#### 5.3 Keyboard Navigation
- Enter key submits from any field (with confirmation)
- Escape closes dropdowns
- Tab order follows logical flow

---

## Implementation Priority

| Phase | Effort | Impact | Priority |
|-------|--------|--------|----------|
| Phase 1: Quick Wins | Low | High | **P0** |
| Phase 2: Validation | Medium | High | **P1** |
| Phase 3: Wizard | High | Very High | **P1** |
| Phase 4: Expert Features | Medium | Medium | **P2** |
| Phase 5: Accessibility | Low | Medium | **P2** |

---

## Mockup: Improved Design

### Before (Current)
```
┌─────────────────────────────────────────┐
│ Create new entity                       │
├─────────────────────────────────────────┤
│        [Create new entity]              │  ← Submit at top?
│ ─────────────────────────────────────── │
│              Gene                       │  ← Center aligned
│ [                                     ] │
│              Disease                    │
│ [                                     ] │
│              Inheritance                │
│ [                                     ] │
│    NDD           Status                 │  ← Split row
│ [      ] [                            ] │
│ ─────────────────────────────────────── │
│           ... more fields ...           │
└─────────────────────────────────────────┘
```

### After (Improved)
```
┌─────────────────────────────────────────────────────────┐
│ Create New Entity                                       │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                         │
│  Step 1        Step 2        Step 3        Step 4       │
│  ●━━━━━━━━━━━━○━━━━━━━━━━━━○━━━━━━━━━━━━○               │
│  Core         Evidence      Phenotype    Review         │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Core Entity Information                        1/4  │ │
│ ├─────────────────────────────────────────────────────┤ │
│ │                                                     │ │
│ │ Gene *                                              │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ Search gene by symbol (e.g., MECP2)             │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ │ Select HGNC gene symbol associated with disease     │ │
│ │                                                     │ │
│ │ Disease *                                           │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ Search disease (e.g., Rett syndrome)            │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ │ Select OMIM or Mondo disease identifier             │ │
│ │                                                     │ │
│ │ Inheritance *                                       │ │
│ │ ┌─────────────────────────────────────────────────┐ │ │
│ │ │ Select inheritance pattern...              ▼    │ │ │
│ │ └─────────────────────────────────────────────────┘ │ │
│ │                                                     │ │
│ │ NDD Phenotype *                                     │ │
│ │ ○ Yes - Neurodevelopmental disorder phenotype       │ │
│ │ ○ No - Not a neurodevelopmental phenotype           │ │
│ │                                                     │ │
│ └─────────────────────────────────────────────────────┘ │
│                                                         │
│                               [Next: Evidence →]        │
│                                                         │
│ ─────────────────────────────────────────────────────── │
│ Draft saved automatically • Last saved: 2 min ago      │
└─────────────────────────────────────────────────────────┘
```

---

## References

### Form Design Best Practices
- [12 Form UI/UX Design Best Practices for 2026](https://www.designstudiouiux.com/blog/form-ux-design-best-practices/)
- [How to Design UI Forms in 2025 | IxDF](https://www.interaction-design.org/literature/article/ui-form-design)
- [8 Form Design Best Practices for 2025 | Buildform](https://buildform.ai/blog/form-design-best-practices/)
- [Form Design Guide | UX Design Institute](https://www.uxdesigninstitute.com/blog/guide-to-form-design-with-tips/)

### Wizard & Multi-Step Forms
- [Wizard UI Pattern | Eleken](https://www.eleken.co/blog-posts/wizard-ui-pattern-explained)
- [Wizards: Definition and Design | NN/g](https://www.nngroup.com/articles/wizards/)
- [PatternFly Wizard Guidelines](https://www.patternfly.org/components/wizard/design-guidelines/)
- [Step Indicator | U.S. Web Design System](https://designsystem.digital.gov/components/step-indicator/)

### Clinical Data Management
- [Clinical Data Management Overview | PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC3326906/)
- [ClinGen Gene Curation Interface](https://clinicalgenome.org/tools/educational-resources/gene-disease-validity-topics/gene-curation-interface/)
- [Database Design for Clinical Research | PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC6230828/)

### Validation & Accessibility
- [Live Validation UX | Smashing Magazine](https://www.smashingmagazine.com/2022/09/inline-validation-web-forms-ux/)
- [Accessible Form Validation | UXPin](https://www.uxpin.com/studio/blog/accessible-form-validation-best-practices/)
- [Inline Validation UX | Baymard](https://baymard.com/blog/inline-form-validation)

---

## Next Steps

1. **Immediate:** Implement Phase 1 quick wins
2. **Short-term:** Add inline validation (Phase 2)
3. **Medium-term:** Design and implement wizard UI (Phase 3)
4. **Long-term:** Expert features and accessibility audit (Phases 4-5)

---

*This review follows industry best practices from Nielsen Norman Group, Baymard Institute, and clinical data management standards from ClinGen and CDISC.*
