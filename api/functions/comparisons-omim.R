# api/functions/comparisons-omim.R
#
# OMIM-NDD comparison source: filter OMIM genemap2 to NDD genes via HPO
# propagated annotations, plus the #502 configurable-seed sensitivity sweep.
# Extracted from comparisons-parsers.R to keep both files < 600 lines.
# Sourced alongside comparisons-parsers.R (setup_workers.R / load_modules.R).

#' Parse OMIM Genemap2 with HPO Phenotype-to-Genes Annotations
#'
#' Filters OMIM genemap2 data to NDD-related genes using the HPO
#' phenotype_to_genes.txt file, which contains pre-propagated HPO hierarchy
#' annotations. Because the annotations are propagated, filtering for a single
#' seed term captures every disease annotated with that term or any of its
#' descendants automatically.
#'
#' The NDD seed term is a parameter (issue #502) so the comparator's NDD
#' definition can be varied for a sensitivity sweep. The default HP:0012759
#' ("Neurodevelopmental abnormality") reproduces the historical published set;
#' defensible alternatives are HP:0001249 ("Intellectual disability", narrower)
#' and HP:0000707 ("Abnormality of the nervous system", broader). See
#' omim_ndd_seed_sweep().
#'
#' @param genemap2_data Pre-parsed tibble from parse_genemap2()
#' @param phenotype_to_genes_path Path to phenotype_to_genes.txt file
#' @param seed_term HPO NDD seed term (default "HP:0012759"). All diseases
#'   annotated (propagated) with this term are treated as NDD.
#'
#' @return Tibble with extracted NDD-related genes
#'
#' @export
adapt_genemap2_for_comparisons <- function(genemap2_data, phenotype_to_genes_path,
                                           seed_term = "HP:0012759") {
  # Read phenotype_to_genes.txt (tab-delimited, 1 header line starting with #)
  ptg <- read_tsv(
    phenotype_to_genes_path,
    comment = "#",
    col_names = c(
      "hpo_id", "hpo_name", "ncbi_gene_id",
      "gene_symbol", "disease_id"
    ),
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )

  # Filter for the NDD seed term (propagated annotations include all descendants)
  # and OMIM diseases only
  ndd_omim_diseases <- ptg %>%
    filter(hpo_id == seed_term) %>%
    filter(str_detect(disease_id, "^OMIM:")) %>%
    dplyr::select(disease_id) %>%
    unique()

  # Join to get NDD genes from pre-parsed genemap2 data
  result <- ndd_omim_diseases %>%
    left_join(
      genemap2_data,
      by = c("disease_id" = "disease_ontology_id")
    ) %>%
    filter(!is.na(Approved_Symbol)) %>%
    mutate(
      list = "omim_ndd",
      version = format(Sys.Date(), "%Y-%m-%d"),
      category = "Definitive"
    ) %>%
    dplyr::select(
      gene_symbol = Approved_Symbol,
      disease_ontology_id = disease_id,
      disease_ontology_name,
      inheritance = hpo_mode_of_inheritance_term_name,
      list,
      version,
      category
    )

  return(result)
}

#' OMIM-NDD seed sensitivity sweep
#'
#' Runs adapt_genemap2_for_comparisons() over a set of NDD seed terms and
#' returns a per-seed summary (gene-set size and, when a SysNDD gene set is
#' supplied, the coverage gap). This is the sensitivity report requested in
#' issue #502; it does NOT change the default published omim_ndd set (which
#' uses seed HP:0012759 via the default argument).
#'
#' @param genemap2_data Pre-parsed tibble from parse_genemap2().
#' @param phenotype_to_genes_path Path to phenotype_to_genes.txt.
#' @param seeds Named character vector of HPO seed terms. Default: narrow
#'   (HP:0001249 "Intellectual disability"), default (HP:0012759
#'   "Neurodevelopmental abnormality"), broad (HP:0000707 "Abnormality of the
#'   nervous system").
#' @param sysndd_symbols Optional character vector of SysNDD gene symbols; when
#'   supplied, coverage-gap columns are added.
#'
#' @return Tibble: seed_label, seed, gene_count, and (when sysndd_symbols is
#'   given) overlap, only_in_omim_ndd, only_in_sysndd.
#'
#' @export
omim_ndd_seed_sweep <- function(genemap2_data, phenotype_to_genes_path,
                                seeds = c(narrow = "HP:0001249",
                                          default = "HP:0012759",
                                          broad = "HP:0000707"),
                                sysndd_symbols = NULL) {
  sysndd_set <- if (!is.null(sysndd_symbols)) unique(toupper(sysndd_symbols)) else NULL

  rows <- lapply(seq_along(seeds), function(i) {
    seed <- unname(seeds[i])
    label <- names(seeds)[i]
    genes <- tryCatch(
      adapt_genemap2_for_comparisons(genemap2_data, phenotype_to_genes_path, seed_term = seed),
      error = function(e) NULL
    )
    gene_syms <- if (is.null(genes)) character(0) else unique(toupper(genes$gene_symbol))

    row <- tibble(
      seed_label = if (is.null(label) || label == "") NA_character_ else label,
      seed = seed,
      gene_count = length(gene_syms)
    )
    if (!is.null(sysndd_set)) {
      row$overlap <- length(intersect(gene_syms, sysndd_set))
      row$only_in_omim_ndd <- length(setdiff(gene_syms, sysndd_set))
      row$only_in_sysndd <- length(setdiff(sysndd_set, gene_syms))
    }
    row
  })

  dplyr::bind_rows(rows)
}

