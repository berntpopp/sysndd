# functions/llm-judge-prompts.R
#
# Judge prompt builders for LLM-as-judge cluster-summary validation.
# Extracted from functions/llm-judge.R (#448) to keep that file under the
# code-quality file-size ratchet; these are pure string builders consumed by
# validate_with_llm_judge(). Sourced before functions/llm-judge.R in
# bootstrap/load_modules.R. The phenotype builder prefers accept_with_corrections
# (with corrected_summary) over hard reject for isolated molecular phrasing and
# allows grounded clinical synthesis of the listed phenotypes (#448).

require(glue)

# Cluster-size threshold (entity count) at/above which the phenotype judge
# applies the relaxed grounding/specificity bar for a high-level GESTALT
# characterization (#490). The largest phenotype cluster (~1000+ entities) is
# defined mostly by broad, weakly-enriched features; under the strict per-claim
# bar the judge deterministically rejects any usable high-level summary of it,
# leaving that cluster stuck "being prepared" forever.
LLM_JUDGE_LARGE_CLUSTER_THRESHOLD <- 300L

#' Build judge prompt for FUNCTIONAL cluster validation
#'
#' Creates validation prompt for functional clusters which group genes by function.
#'
#' @param summary List, the generated summary to validate
#' @param cluster_data List, the original cluster data
#'
#' @return Character string, the formatted judge prompt
#'
#' @keywords internal
build_functional_judge_prompt <- function(summary, cluster_data) {
  # Extract context for judge
  genes <- if ("identifiers" %in% names(cluster_data) && "symbol" %in% names(cluster_data$identifiers)) {
    gene_list <- cluster_data$identifiers$symbol
    if (length(gene_list) > 20) {
      paste0(paste(head(gene_list, 15), collapse = ", "), "... (", length(gene_list), " total)")
    } else {
      paste(gene_list, collapse = ", ")
    }
  } else {
    "(genes not available)"
  }

  # Extract top 20 enrichment terms PER CATEGORY for validation

  # CRITICAL: Must match the generation prompt which uses top_n_terms = 20 per category
  # Previous bug: used slice_head(n=15) globally, so judge only saw 15 terms total
  # while generator showed 20 per category (potentially 80+ terms)
  enrichment_terms <- if ("term_enrichment" %in% names(cluster_data) && nrow(cluster_data$term_enrichment) > 0) {
    cluster_data$term_enrichment %>%
      dplyr::group_by(category) %>%
      dplyr::arrange(fdr) %>%
      dplyr::slice_head(n = 20) %>%
      dplyr::ungroup() %>%
      dplyr::mutate(
        display_name = dplyr::if_else(!is.na(description) & description != "", description, term),
        term_line = glue::glue("- {category}: {display_name} (FDR: {signif(fdr, 3)})")
      ) %>%
      dplyr::pull(term_line) %>%
      paste(collapse = "\n")
  } else {
    "(no enrichment data)"
  }

  # Extract summary components
  summary_text <- summary$summary %||% ""
  key_themes <- if (!is.null(summary$key_themes) && length(summary$key_themes) > 0) {
    paste(summary$key_themes, collapse = ", ")
  } else {
    "(none)"
  }
  pathways <- if (!is.null(summary$pathways) && length(summary$pathways) > 0) {
    paste(summary$pathways, collapse = ", ")
  } else {
    "(none)"
  }
  self_confidence <- summary$confidence %||% "unknown"

  glue::glue("
You are a STRICT scientific accuracy validator for AI-generated gene cluster summaries.
Your task is to DETECT HALLUCINATIONS and verify the summary is accurately grounded in the provided data.

## Original Cluster Data
**Genes:** {genes}

**Top 20 Enrichment Terms per Category (AUTHORITATIVE SOURCE):**
{enrichment_terms}

## Generated Summary to Validate
**Summary text:** {summary_text}

**Key themes:** {key_themes}

**Pathways listed:** {pathways}

**Self-assessed confidence:** {self_confidence}

---

## MANDATORY VERIFICATION CHECKLIST

Complete each verification step before rendering your verdict.

### Step 1: Pathway String Matching (CRITICAL)
For EACH pathway listed in the summary:
- Does it appear VERBATIM in the enrichment terms? (YES/NO)
- If NO, is it a reasonable synonym of an existing term? (YES/NO)
- If neither, mark as INVENTED

**Scoring:**
- All pathways appear verbatim = +2 points
- Minor generalizations only = +1 point
- Any completely invented pathway = 0 points

### Step 2: Theme Grounding Check
For EACH key theme, identify which enrichment terms support it.
- Theme with supporting term(s) = GROUNDED
- Theme with NO supporting terms = UNGROUNDED

**Scoring:**
- All themes grounded = +2 points
- 1-2 ungrounded but reasonable = +1 point
- 3+ ungrounded themes = 0 points

### Step 3: Invented Term Detection
List ANY terms, pathways, or mechanisms in the summary that:
- Do NOT appear in the enrichment terms AND
- Cannot be directly inferred from the enrichment data

**Scoring:**
- No invented terms = +2 points
- 1-2 minor invented terms = +1 point
- Any significant hallucination = 0 points

### Step 4: Confidence Calibration
Compare self-assessed confidence to evidence strength:
- High appropriate if: Multiple terms with FDR < 1E-50
- Medium appropriate if: Terms with FDR between 1E-10 and 1E-50
- Low appropriate if: Terms with FDR > 1E-10 or few terms

**Scoring:**
- Confidence matches evidence = +2 points
- Off by one level = +1 point
- Significantly mismatched = 0 points

---

## VERDICT CALCULATION (with Corrections)

**Total your points from Steps 1-4 (maximum 8 points):**

| Points | Verdict | Action |
|--------|---------|--------|
| 7-8 | **accept** | Cache as 'validated' |
| 5-6 | **accept_with_corrections** | Apply corrections, cache as 'validated' |
| 3-4 | **low_confidence** | Cache as 'pending' for review |
| 0-2 | **reject** | Do not cache, trigger regeneration |

**IMPORTANT: Prefer accept_with_corrections over reject when possible**

---

## CORRECTION INSTRUCTIONS

For scores 5-6, if issues are correctable:
1. Set corrections_needed = true
2. List corrections in corrections_made array
3. Provide corrected_tags with ONLY valid pathway/functional terms from input
4. Use verdict = 'accept_with_corrections'

Only REJECT (score 0-2) if:
- Summary fundamentally misrepresents the cluster
- Multiple severe hallucinations that can't be corrected
- Core summary text is inaccurate (not just tags/metadata)

---

## EXAMPLES

### Example: ACCEPT (8 points)
- 'PI3K-Akt signaling pathway' appears verbatim in KEGG terms (+2)
- All themes map to specific enrichment terms (+2)
- No invented terms found (+2)
- Medium confidence for FDR ~1E-30 terms (+2)

### Example: ACCEPT_WITH_CORRECTIONS (6 points)
- Pathway name slightly paraphrased but correct meaning (+1)
- Most themes grounded, one tag not in data - CORRECT IT (+2)
- One invented term in tags - REMOVE IT (+1)
- Confidence matches evidence (+2)
- corrections_made: ['Removed \"axon guidance\" from tags - not in KEGG data']

### Example: LOW_CONFIDENCE (4 points)
- 'Ras/MAPK cascade' but data shows 'Ras signaling pathway' separately (+1)
- Most themes grounded, one reasonable inference (+1)
- One term not in enrichment data (+0)
- Confidence matches evidence (+2)

### Example: REJECT (2 points)
- 'Wnt signaling pathway' NOT in enrichment data (+0)
- 'epigenetic regulation' but no epigenetic terms in data (+0)
- Multiple invented mechanisms (+0)
- High confidence despite weak enrichment (+2)

---

## YOUR RESPONSE
Complete the verification steps, calculate total points, then provide your verdict.
")
}


#' Build judge prompt for PHENOTYPE cluster validation
#'
#' Creates validation prompt for phenotype clusters which group disease entities
#' by phenotype patterns using v.test scores.
#'
#' @param summary List, the generated summary to validate
#' @param cluster_data List, the original cluster data
#'
#' @return Character string, the formatted judge prompt
#'
#' @keywords internal
build_phenotype_judge_prompt <- function(summary, cluster_data) {
  # Extract phenotype data from quali_inp_var
  phenotype_terms <- if ("quali_inp_var" %in% names(cluster_data)) {
    phenotypes_df <- if (is.data.frame(cluster_data$quali_inp_var)) {
      cluster_data$quali_inp_var
    } else if (is.list(cluster_data$quali_inp_var)) {
      dplyr::bind_rows(cluster_data$quali_inp_var)
    } else {
      NULL
    }

    if (!is.null(phenotypes_df) && nrow(phenotypes_df) > 0 &&
        all(c("variable", "v.test") %in% names(phenotypes_df))) {
      phenotypes_df %>%
        dplyr::arrange(dplyr::desc(abs(`v.test`))) %>%
        dplyr::slice_head(n = 15) %>%
        dplyr::mutate(
          direction = dplyr::if_else(`v.test` > 0, "ENRICHED", "DEPLETED"),
          term_line = glue::glue("- {variable}: v.test={round(`v.test`, 2)} [{direction}]")
        ) %>%
        dplyr::pull(term_line) %>%
        paste(collapse = "\n")
    } else {
      "(no phenotype data)"
    }
  } else {
    "(no phenotype data)"
  }

  # Extract inheritance patterns from quali_sup_var
  inheritance_terms <- "(no inheritance data)"
  if ("quali_sup_var" %in% names(cluster_data) && length(cluster_data$quali_sup_var) > 0) {
    inheritance_df <- if (is.data.frame(cluster_data$quali_sup_var)) {
      cluster_data$quali_sup_var
    } else if (is.list(cluster_data$quali_sup_var)) {
      dplyr::bind_rows(cluster_data$quali_sup_var)
    } else {
      NULL
    }

    if (!is.null(inheritance_df) && nrow(inheritance_df) > 0 &&
        all(c("variable", "v.test") %in% names(inheritance_df))) {
      sig_inheritance <- inheritance_df %>%
        dplyr::filter(abs(`v.test`) > 2) %>%
        dplyr::arrange(dplyr::desc(`v.test`))

      if (nrow(sig_inheritance) > 0) {
        inheritance_terms <- sig_inheritance %>%
          dplyr::mutate(
            direction = dplyr::if_else(`v.test` > 0, "ENRICHED", "DEPLETED"),
            term_line = glue::glue("- {variable}: v.test={round(`v.test`, 2)} [{direction}]")
          ) %>%
          dplyr::pull(term_line) %>%
          paste(collapse = "\n")
      }
    }
  }

  # Extract syndromicity metrics from quanti_sup_var
  syndromicity_terms <- "(no syndromicity data)"
  if ("quanti_sup_var" %in% names(cluster_data) && length(cluster_data$quanti_sup_var) > 0) {
    quanti_df <- if (is.data.frame(cluster_data$quanti_sup_var)) {
      cluster_data$quanti_sup_var
    } else if (is.list(cluster_data$quanti_sup_var)) {
      dplyr::bind_rows(cluster_data$quanti_sup_var)
    } else {
      NULL
    }

    if (!is.null(quanti_df) && nrow(quanti_df) > 0 &&
        all(c("variable", "v.test") %in% names(quanti_df))) {
      sig_quanti <- quanti_df %>%
        dplyr::filter(abs(`v.test`) > 2) %>%
        dplyr::arrange(dplyr::desc(abs(`v.test`)))

      if (nrow(sig_quanti) > 0) {
        syndromicity_terms <- sig_quanti %>%
          dplyr::mutate(
            direction = dplyr::if_else(`v.test` > 0, "HIGHER", "LOWER"),
            term_line = glue::glue("- {variable}: v.test={round(`v.test`, 2)} [{direction} than average]")
          ) %>%
          dplyr::pull(term_line) %>%
          paste(collapse = "\n")
      }
    }
  }

  # Get entity count
  entity_count <- if ("identifiers" %in% names(cluster_data)) {
    nrow(cluster_data$identifiers)
  } else {
    "unknown"
  }

  # Large-cluster relaxation note (#490). For a very large, heterogeneous cluster
  # a grounded high-level GESTALT characterization at a relaxed grounding /
  # specificity bar is accept / accept_with_corrections, NOT reject. Empty for
  # normal-sized clusters so their strict bar is unchanged.
  entity_count_numeric <- suppressWarnings(as.integer(entity_count))
  is_large_cluster <- !is.na(entity_count_numeric) &&
    entity_count_numeric >= LLM_JUDGE_LARGE_CLUSTER_THRESHOLD
  large_cluster_note <- if (is_large_cluster) {
    glue::glue("
## LARGE, HETEROGENEOUS CLUSTER -> RELAXED BAR ({entity_count} entities)
This cluster is LARGE and heterogeneous. It is defined largely by BROAD,
weakly-enriched features (and strong DEPLETIONS), so no narrow, highly specific
phenotype gestalt exists. Judge it accordingly:
- A grounded, HIGH-LEVEL GESTALT characterization of the overall cluster
  (e.g. 'a broad, predominantly non-syndromic neurodevelopmental presentation
  with mild intellectual disability and behavioral features, lacking severe
  malformations') is ACCEPTABLE at a RELAXED grounding / specificity bar.
- For a large cluster, prefer 'accept' or 'accept_with_corrections' for such a
  grounded high-level summary; do NOT 'reject' merely because the summary is
  broad, high-level, or omits low-|v.test| terms.
- The severe-error hard rejects (fundamentally molecular mechanism, direction
  inversion, a fabricated NEW specific phenotype) STILL apply.
")
  } else {
    ""
  }

  # Extract summary components (phenotype-specific fields)
  summary_text <- summary$summary %||% ""

  # Handle both old (key_themes) and new (key_phenotype_themes) field names
  key_themes <- if (!is.null(summary$key_phenotype_themes) && length(summary$key_phenotype_themes) > 0) {
    paste(summary$key_phenotype_themes, collapse = ", ")
  } else if (!is.null(summary$key_themes) && length(summary$key_themes) > 0) {
    paste(summary$key_themes, collapse = ", ")
  } else {
    "(none)"
  }

  notably_absent <- if (!is.null(summary$notably_absent) && length(summary$notably_absent) > 0) {
    paste(summary$notably_absent, collapse = ", ")
  } else {
    "(not specified)"
  }

  clinical_pattern <- summary$clinical_pattern %||% "(not specified)"
  self_confidence <- summary$confidence %||% "unknown"

  # Extract new supplementary fields
  inheritance_patterns <- if (!is.null(summary$inheritance_patterns) && length(summary$inheritance_patterns) > 0) {
    paste(summary$inheritance_patterns, collapse = ", ")
  } else {
    "(not specified)"
  }

  syndromicity <- summary$syndromicity %||% "(not specified)"

  glue::glue("
You are a STRICT validator for AI-generated phenotype cluster summaries.
Your job is to DETECT HALLUCINATIONS and REJECT inaccurate summaries.

## CRITICAL CONTEXT
- This cluster contains {entity_count} DISEASE ENTITIES (gene-disease associations)
- Entities were clustered by PHENOTYPE PATTERNS, NOT by gene function
- The summary MUST describe CLINICAL PHENOTYPES, not molecular mechanisms
- v.test interpretation: POSITIVE = phenotype ENRICHED, NEGATIVE = phenotype DEPLETED
{large_cluster_note}
---

## SEVERE ERRORS (verdict = 'reject')
Reject ONLY for these severe, non-correctable errors:

1. **FUNDAMENTALLY MOLECULAR**: The summary's main point is a molecular MECHANISM
   rather than a clinical phenotype description.
   - REJECT if: 'these genes drive synaptic signaling and chromatin remodeling'
   - REJECT if: the summary explains *why* (mechanism) instead of *what* (phenotype)

2. **FABRICATED SPECIFIC PHENOTYPE**: Summary asserts a NEW specific phenotype that
   is NOT in the input data (and is not a grounded synthesis of listed terms).
   - REJECT if: summary says 'epilepsy' but no seizure term is in the input
   - REJECT if: summary says 'cardiac defects' but no heart-related term is in the input

3. **DIRECTION INVERSION**: Summary describes enriched phenotypes as depleted or vice versa
   - REJECT if: v.test is NEGATIVE but summary says 'strongly associated with' or 'enriched'
   - REJECT if: v.test is POSITIVE but summary says 'absent' or 'depleted'

---

## GROUNDED CLINICAL SYNTHESIS IS ALLOWED (do NOT treat as fabrication)
Synthesizing or grouping the LISTED phenotypes into a recognized clinical gestalt
is grounded clinical synthesis, not hallucination. A cluster defined mostly by
what is DEPLETED (few enriched terms) can be legitimately summarized by that
overall character.
- ALLOWED: describing mild-ID + macrocephaly + behavioral-abnormality enrichment
  (with strong depletion of severe/profound features) as 'a mild, predominantly
  non-syndromic neurodevelopmental presentation'.
- ALLOWED: grouping listed phenotypes into a clinical category (e.g. 'renal and
  genitourinary features') when those phenotypes appear in the data.
- The line: it is fabrication ONLY when a NEW specific phenotype absent from the
  tables is asserted - not when the listed phenotypes are summarized as a whole.

## ISOLATED MOLECULAR PHRASING -> CORRECT, DON'T REJECT
A molecular-sounding word can appear inside a legitimate clinical phenotype name
(e.g. 'Elevated circulating creatine kinase concentration') or as an isolated
slip. When the summary is otherwise grounded clinical prose and the ONLY problem
is one or two molecular words/phrases, prefer 'accept_with_corrections' and return
a 'corrected_summary' that rephrases or removes the molecular wording. Reserve
'reject' for summaries that are FUNDAMENTALLY about mechanism (Severe Error 1).

Molecular-mechanism vocabulary to scrub from prose (NOT from grounded phenotype
names): gene, protein, pathway, signaling, transcription, chromatin, histone,
methylation, enzyme, receptor, kinase, mTOR, MAPK, DNA repair, RNA processing,
cell cycle, 'plays a role in', 'involved in', 'functions in', 'regulates',
'modulates'.

---

## INPUT DATA (Ground Truth)

### Primary Phenotypes (used for clustering)
{phenotype_terms}

### Supplementary Data (describes cluster characteristics)
**Inheritance patterns (from HPO):**
{inheritance_terms}

**Syndromicity metrics:**
{syndromicity_terms}

---

## SUMMARY TO VALIDATE
**Summary text:** {summary_text}

**Key phenotype themes:** {key_themes}

**Notably absent phenotypes:** {notably_absent}

**Clinical pattern:** {clinical_pattern}

**Inheritance patterns:** {inheritance_patterns}

**Syndromicity:** {syndromicity}

**Self-assessed confidence:** {self_confidence}

---

## STEP-BY-STEP VERIFICATION (Complete ALL steps before verdict)

**Step 1 - Molecular-Mechanism Scan (FIRST!):**
Check whether the summary is fundamentally about a molecular MECHANISM.
- If the main point is mechanism (Severe Error 1): verdict = 'reject'.
- If there is only isolated molecular phrasing in otherwise-clinical prose, OR a
  molecular-sounding word that is part of a grounded phenotype name (e.g.
  'creatine kinase'): do NOT reject - prefer 'accept_with_corrections' and supply
  a 'corrected_summary' that rephrases/removes the molecular wording.

**Step 2 - Extract Claims:**
List every phenotype or clinical term mentioned in the summary.

**Step 3 - Ground Each Claim:**
For EACH term from Step 2, verify it exists in the input phenotype data (exact or
semantically equivalent), OR is a grounded clinical synthesis of listed terms.
Mark a term as FABRICATED only when it asserts a NEW specific phenotype absent
from the input - not when it summarizes the listed phenotypes as a whole.

**Step 4 - Direction Check:**
For phenotypes described as enriched, verify v.test > 0.
For phenotypes described as depleted, verify v.test < 0.
Mark mismatches as DIRECTION_ERROR.

**Step 5 - Calculate Grounding Score:**
Grounding % = (number of grounded claims / total claims) x 100

**Step 6 - Inheritance Pattern Check:**
For each inheritance pattern in the summary:
- Verify it appears in the inheritance data (quali_sup_var) with |v.test| > 2
- Standard abbreviations: AD=Autosomal dominant, AR=Autosomal recessive, XL=X-linked, MT=Mitochondrial
- Mark as INVALID if pattern not in source data

**Step 7 - Syndromicity Check:**
Compare summary's syndromicity claim against quanti_sup_var data:
- 'predominantly_syndromic' should match positive v.test for phenotype_non_id_count
- 'predominantly_id' should match positive v.test for phenotype_id_count
- 'mixed' is valid if both or neither significant
- 'unknown' is valid if no syndromicity data
- Mark as INVALID if mismatch

---

## VERDICT CRITERIA (with Corrections)

**IMPORTANT: Prefer CORRECTING minor issues over REJECTING**

**REJECT (only for SEVERE, non-correctable issues):**
- Summary is FUNDAMENTALLY about a molecular mechanism (Severe Error 1)
- Direction inversion in main summary description (Step 4)
- Grounding score < 50% in main summary
- Multiple fabricated SPECIFIC phenotypes that fundamentally misrepresent the cluster

**ACCEPT_WITH_CORRECTIONS (correctable issues - PREFER THIS over reject):**
- Isolated molecular phrasing in otherwise-clinical prose → set corrected_summary
  with the molecular wording rephrased/removed
- One over-reaching label or phrase in the main summary → set corrected_summary
  trimmed to the grounded phenotypes
- Tags array contains items not in input data → Remove them, list in corrections_made
- Notably_absent array contains items not in input data → Remove them, list in corrections_made
- One or two phenotype terms need adjustment → Provide corrected list
- Main summary is accurate but supporting fields have minor issues

**LOW_CONFIDENCE (moderate issues, no correction possible):**
- Grounding score 50-79%
- Uses overly broad syndrome terms that can't be corrected
- Missing significant phenotypes from top 5 by |v.test|

**ACCEPT (all must be true):**
- Grounding score >= 80%
- No molecular/gene content
- No fabricated phenotypes in main summary
- Direction interpretation correct
- All tags and notably_absent items verified in input data

---

## CORRECTION INSTRUCTIONS

If issues are correctable:
1. Set corrections_needed = true
2. List each correction in corrections_made array
3. Provide corrected_tags with ONLY items that appear in the input phenotype data
4. Provide corrected_notably_absent with ONLY depleted phenotypes (v.test < 0) from input
5. Provide corrected_inheritance_patterns with ONLY patterns from quali_sup_var with |v.test| > 2
   - Use standard abbreviations: AD, AR, XL, XLR, XLD, MT, SP
6. Provide corrected_syndromicity based on quanti_sup_var data
7. If the MAIN summary text needed wording fixes (isolated molecular phrasing or
   an over-reaching label), provide corrected_summary with grounded clinical
   prose; otherwise leave corrected_summary empty
8. Use verdict = 'accept_with_corrections'

Example correction:
- corrections_made: ['Removed \"Seizures\" from notably_absent - not in input data',
  'Corrected inheritance from XL to AR based on source data']
- corrected_notably_absent: ['Progressive', 'Developmental regression'] (only items with v.test < 0)
- corrected_inheritance_patterns: ['AR', 'AD'] (only from source data)
- corrected_syndromicity: 'predominantly_id' (based on positive v.test for phenotype_id_count)

---

## YOUR RESPONSE
Complete the verification steps, then provide your verdict.
REMEMBER: Prefer 'accept_with_corrections' (supply a grounded corrected_summary)
over 'reject' for isolated molecular phrasing or a single over-reaching label.
Reject ONLY when the summary is fundamentally about a molecular mechanism,
inverts enrichment direction, fabricates a NEW specific phenotype, or falls below
50% grounding. Grounded clinical synthesis of the listed phenotypes is acceptable.
")
}
