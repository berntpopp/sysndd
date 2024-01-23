



pmids_request <- pubtator_v3_pmids_from_request(query = '("intellectual disability" OR "mental retardation" OR "autism" OR "epilepsy" OR "neurodevelopmental disorder" OR "neurodevelopmental disease" OR "epileptic encephalopathy") AND (gene OR syndrome) AND (variant OR mutation)', start_page = 1, max_pages = 1)

request_data <- pubtator_v3_data_from_pmids(pmids_request$pmid)

final_results <- pubtator_v3_extract_gene_from_annotations(request_data)

