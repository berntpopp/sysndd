# sysndd_plumber.R


##-------------------------------------------------------------------##
# load libraries
library(biomaRt)
library(plumber)
library(tidyverse)
library(stringr)
library(DBI)
library(RMariaDB)
library(jsonlite)
library(config)
library(jose)
library(RCurl)
library(stringdist)
library(xlsx)
library(easyPubMed)
library(xml2)
library(rvest)
library(lubridate)
library(pool)
library(memoise)
library(coop)
library(reshape2)
library(blastula)
library(keyring)
library(future)
library(knitr)
library(rlang)
library(timetk)
library(STRINGdb)
library(factoextra)
library(FactoMineR)
library(vctrs)
library(httr)
library(ellipsis)
library(ontologyIndex)
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
# load config
dw <- config::get(Sys.getenv("API_CONFIG"))
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## global variables

# smtp password if not set
if (nchar(Sys.getenv("SMTP_PASSWORD")) == 0) {
  Sys.setenv("SMTP_PASSWORD" = toString(dw$mail_noreply_password))
}

# time as GMT
Sys.setenv(TZ = "GMT")
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
# generate a pool of connections to the database
pool <- dbPool(
  drv = RMariaDB::MariaDB(),
  dbname = dw$dbname,
  host = dw$host,
  user = dw$user,
  password = dw$password,
  server = dw$server,
  port = dw$port
)
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## global variables
serializers <- list(
  "json" = serializer_json(),
  "xlsx" = serializer_content_type(type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
)

# TODO: This needs to go into the database as helper
# TODO: this might me deprecated as the panels EP now has filtering
inheritance_input_allowed <- c("X-linked",
  "Autosomal dominant",
  "Autosomal recessive",
  "Other",
  "All")

# TODO: This needs to go into the database as helper
# TODO: this might me deprecated as the panels EP now has filtering
output_columns_allowed <- c("category",
  "inheritance",
  "symbol",
  "hgnc_id",
  "entrez_id",
  "ensembl_gene_id",
  "ucsc_id",
  "bed_hg19",
  "bed_hg38")

# TODO: This needs to go into the database as helper
user_status_allowed <- c("Administrator",
  "Curator",
  "Reviewer",
  "Viewer")
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
##-------------------------------------------------------------------##
# Global API functions
options("plumber.apiURL" = dw$api_base_url)

# load source files
source("functions/database-functions.R", local = TRUE)
source("functions/endpoint-functions.R", local = TRUE)
source("functions/publication-functions.R", local = TRUE)
source("functions/genereviews-functions.R", local = TRUE)
source("functions/analyses-functions.R", local = TRUE)
source("functions/helper-functions.R", local = TRUE)
source("functions/external-functions.R", local = TRUE)
source("functions/logging-functions.R", local = TRUE)
source("functions/file-functions.R", local = TRUE)

source("functions/hpo-functions.R", local = TRUE)
source("functions/hgnc-functions.R", local = TRUE)
source("functions/ontology-functions.R", local = TRUE)
source("functions/pubtator-functions.R", local = TRUE)
source("functions/ensembl-functions.R", local = TRUE)

# convert to memoise functions
# Expire items in cache after 60 minutes
# and set cache 100 MB limit
cm <- cachem::cache_mem(max_age = 60 * 60,
  max_size = 100 * 1024 ^ 2)

generate_stat_tibble_mem <- memoise(generate_stat_tibble,
  cache = cm)

generate_gene_news_tibble_mem <- memoise(generate_gene_news_tibble,
  cache = cm)

nest_gene_tibble_mem <- memoise(nest_gene_tibble,
  cache = cm)

generate_tibble_fspec_mem <- memoise(generate_tibble_fspec,
  cache = cm)

gen_string_clust_obj_mem <- memoise(gen_string_clust_obj,
  cache = cm)

gen_mca_clust_obj_mem <- memoise(gen_mca_clust_obj,
  cache = cm)

read_log_files_mem <- memoise(read_log_files,
  cache = cm)

# function to get the API version
# based on https://stackoverflow.com/questions/65021158/programmatically-use-apiversion-with-plumber
#' @plumber
function(pr) {
  assign("apiV",
         function() {
           pr$.__enclos_env__$private$globalSettings$info$version
         },
         envir = pr$environment)
}
##-------------------------------------------------------------------##
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
##-------------------------------------------------------------------##
#* @apiTitle SysNDD API

#* @apiDescription This is the API powering the SysNDD website
#* and allowing programmatic access to the database contents.
#* @apiVersion 0.1.0
#* @apiTOS https://sysndd.dbmr.unibe.ch/About
#* @apiContact list(name = "API Support",
#* url = "https://berntpopp.github.io/sysndd/api.html",
#* email = "support@sysndd.org")
#* @apiLicense list(name = "CC BY 4.0",
#* url = "https://creativecommons.org/licenses/by/4.0/")

#* @apiTag entity Entity related endpoints
#* @apiTag review Reviews related endpoints
#* @apiTag status Status related endpoints
#* @apiTag re_review Re-review related endpoints
#* @apiTag publication Publication related endpoints
#* @apiTag gene Gene related endpoints
#* @apiTag ontology Ontology related endpoints
#* @apiTag phenotype Phenotype related endpoints
#* @apiTag panels Gene panel related endpoints
#* @apiTag comparisons NDD gene list comparisons related endpoints
#* @apiTag analysis Analyses related endpoints
#* @apiTag hash Database list hashing endpoints for reproducible long requests
#* @apiTag search Database search related endpoints
#* @apiTag list Database list related endpoints
#* @apiTag statistics Database statistics
#* @apiTag external Interaction with external resources
#* @apiTag logging Logging related endpoints
#* @apiTag user User account related endpoints
#* @apiTag authentication Authentication related endpoints
#* @apiTag admin Administration related endpoints
##-------------------------------------------------------------------##
##-------------------------------------------------------------------##


##-------------------------------------------------------------------##
## hooks

#* @plumber
function(pr) {
  pr %>%
    plumber::pr_hook("exit", function() {
      pool::poolClose(pool)
      message("Disconnected")
    })
}
##-------------------------------------------------------------------##


##-------------------------------------------------------------------##
## filters

#* @filter cors
#* enables cross origin requests
## based on https://github.com/rstudio/plumber/issues/66
function(req, res) {

  res$setHeader("Access-Control-Allow-Origin", "*")

  if (req$REQUEST_METHOD == "OPTIONS") {
    res$setHeader("Access-Control-Allow-Methods", "*")
    res$setHeader("Access-Control-Allow-Headers",
      req$HTTP_ACCESS_CONTROL_REQUEST_HEADERS)
    res$status <- 200
    return(list())
  } else {
    plumber::forward()
  }
}


#* @filter check_signin
#* checks signin from header token and set user variable to request
function(req, res) {
  # load secret and convert to raw
  key <- charToRaw(dw$secret)

  if (req$REQUEST_METHOD == "GET" && is.null(req$HTTP_AUTHORIZATION)) {
    plumber::forward()
  } else if (req$REQUEST_METHOD == "GET" && !is.null(req$HTTP_AUTHORIZATION)) {
    # load jwt from header
    jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")

    # decode jwt
    tryCatch({
      user <- jwt_decode_hmac(str_remove(req$HTTP_AUTHORIZATION, "Bearer "),
        secret = key)
    }, error = function(e) {
      res$status <- 401 # Unauthorized
      return(list(error = "Token expired or invalid."))
    })

    # add user_id and user_role as value to request
    req$user_id <- as.integer(user$user_id)
    req$user_role <- user$user_role

    # and forward request
    plumber::forward()
  } else if (req$REQUEST_METHOD == "POST" &&
      (req$PATH_INFO == "/api/gene/hash" ||
      req$PATH_INFO == "/api/entity/hash")) {
    # and forward request
    plumber::forward()
  } else {
    if (is.null(req$HTTP_AUTHORIZATION)) {
      res$status <- 401 # Unauthorized
      return(list(error = "Authorization http header missing."))
    } else if (jwt_decode_hmac(str_remove(req$HTTP_AUTHORIZATION, "Bearer "),
        secret = key)$exp < as.numeric(Sys.time())) {
      res$status <- 401 # Unauthorized
      return(list(error = "Token expired."))
    } else {
      # load jwt from header
      jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")
      # decode jwt
      user <- jwt_decode_hmac(str_remove(req$HTTP_AUTHORIZATION, "Bearer "),
        secret = key)
      # add user_id and user_role as value to request
      req$user_id <- as.integer(user$user_id)
      req$user_role <- user$user_role
      # and forward request
      plumber::forward()
    }
  }
}
##-------------------------------------------------------------------##


##-------------------------------------------------------------------##
## Entity endpoints

#* Get a Cursor Pagination Object of All Entities
#*
#* This endpoint returns a cursor pagination object of all entities based on the
#* data in the database.
#*
#* # `Details`
#* This is a plumber endpoint function that retrieves paginated data from a
#* database table and returns it as a JSON response. The function takes input
#* parameters for sorting, filtering, and field selection, and uses cursor
#* pagination to generate links to previous and next pages.
#* It retrieves data from two tables in the database, filters and sorts the data
#* based on input parameters, selects fields for inclusion in the response, and
#* generates pagination information and fields specifications.
#* The function adds meta and link information to the response and computes
#* execution time before returning the paginated data as a list.
#*
#* # `Return`
#* A cursor pagination object containing a list of entities.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sort:str Output column to arrange output on.
#* @param filter:str Comma separated list of filters to apply.
#* @param fields:str Comma separated list of output columns.
#* @param page_after:str Cursor after which entries are shown.
#* @param page_size:str Page size in cursor pagination.
#* @param fspec:str Fields to generate field specification for.
#*
#* @response 200 OK. A cursor pagination object with links, meta and data (entity objects).
#* @response 500 Internal server error.
#*
#* @get /api/entity
function(req,
  res,
  sort = "entity_id",
  filter = "",
  fields = "",
  `page_after` = 0,
  `page_size` = "10",
  fspec = "entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details",
  format = "json") {
  # set serializers
  res$serializer <- serializers[[format]]

  # TODO: Put all of this into and endpoint function
  # start time calculation
  start_time <- Sys.time()

  # generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "entity_id")

  # generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # get review data from database
  ndd_entity_review <- pool %>%
    tbl("ndd_entity_review") %>%
    filter(is_primary) %>%
    dplyr::select(entity_id, synopsis)

  # get entity data from database
  # '!!!' in filter needed to evaluate formula for any/ all
  # cases (see "https://stackoverflow.com/questions/
  # 66070864/operating-across-columns-rowwise-in-r-dbplyr")
  ndd_entity_view <- pool %>%
    tbl("ndd_entity_view") %>%
    left_join(ndd_entity_review, by = c("entity_id")) %>%
    collect()

  sysndd_db_disease_table <- ndd_entity_view %>%
    arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
    filter(!!!rlang::parse_exprs(filter_exprs))

  # select fields from table based on input
  # using the helper function "select_tibble_fields"
  sysndd_db_disease_table <- select_tibble_fields(sysndd_db_disease_table,
    fields,
    "entity_id")

  # use the helper generate_cursor_pag_inf to
  # generate cursor pagination information from a tibble
  disease_table_pagination_info <- generate_cursor_pag_inf(
    sysndd_db_disease_table,
    `page_size`,
    `page_after`,
    "entity_id")

  # use the helper generate_tibble_fspec to
  # generate fields specs from a tibble
  # first for the unfiltered and not subset table
  disease_table_fspec <- generate_tibble_fspec_mem(ndd_entity_view,
    fspec)
  # then for the filtered/ subset one
  sysndd_db_disease_table_fspec <- generate_tibble_fspec_mem(
    sysndd_db_disease_table,
    fspec)
  # assign the second to the first as filtered
  disease_table_fspec$fspec$count_filtered <-
    sysndd_db_disease_table_fspec$fspec$count

  # compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(paste0(round(end_time - start_time, 2),
    " secs"))

  # add columns to the meta information from
  # generate_cursor_pag_inf function return
  meta <- disease_table_pagination_info$meta %>%
    add_column(tibble::as_tibble(list("sort" = sort,
    "filter" = filter,
    "fields" = fields,
    "fspec" = disease_table_fspec,
    "executionTime" = execution_time)))

  # add host, port and other information to links from
  # the link information from generate_cursor_pag_inf function return
  links <- disease_table_pagination_info$links %>%
      pivot_longer(everything(), names_to = "type", values_to = "link") %>%
    mutate(link = case_when(
      link != "null" ~ paste0(
        dw$api_base_url,
        "/api/entity?sort=",
        sort,
        ifelse(filter != "", paste0("&filter=", filter), ""),
        ifelse(fields != "", paste0("&fields=", fields), ""),
        link),
      link == "null" ~ "null"
    )) %>%
      pivot_wider(id_cols = everything(), names_from = "type", values_from = "link")

  # generate object to return
  entities_list <- list(links = links,
    meta = meta,
    data = disease_table_pagination_info$data)

  # if xlsx requested compute this and return
  if (format == "xlsx") {
    # generate creation date statistic for output
    creation_date <- strftime(as.POSIXlt(Sys.time(),
      "UTC",
      "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S")

    # generate base filename from api name
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
        str_replace_all("_api_", "")

    filename <- file.path(paste0(base_filename,
      "_",
      creation_date,
      ".xlsx"))

    # generate xlsx bin using helper function
    bin <- generate_xlsx_bin(entities_list, base_filename)

    # Return the binary contents
    as_attachment(bin, filename)
  } else {
    entities_list
  }
}


#* Create New Entity
#*
#* This endpoint allows for the creation of a new entity,
#* including entity details, review, and status.
#* It also provides options for direct approval,
#* review of literature, synopsis, phenotypes, and variation ontology.
#*
#* # `Details`
#* The function checks for user rights, and if valid,
#* proceeds to create a new entity. Subsequent checks are performed
#* to review the entity and create status. The function also handles
#* different scenarios like empty publications, phenotypes, and
#* variation ontology.
#*
#* # `Return`
#* A list with status and message of the operation or an
#* error message if user has no write access.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param direct_approval Boolean for direct approval. Defaults to FALSE.
#*
#* @post /api/entity/create
function(req, res, direct_approval = FALSE) {

  # make sure direct_approval input is logical
  direct_approval <- as.logical(direct_approval)

  # assign request JSON to variable
  create_data <- req$argsBody$create_json

  # first check rights
  if (req$user_role %in% c("Administrator", "Curator")) {

    # define user variables
    entry_user_id <- req$user_id
    review_user_id <- req$user_id
    status_user_id <- req$user_id

    create_data$entity$entry_user_id <- entry_user_id

    ##-------------------------------------------------------------------##
    # block to post new entity
    response_entity <- post_db_entity(create_data$entity)
    ##-------------------------------------------------------------------##

    if (response_entity$status == 200) {
    ##-------------------------------------------------------------------##
    # block to post new review for posted entity
      ##-------------------------------------------------------------------##
      # data preparation
      # convert publications to tibble
      if (length(compact(create_data$review$literature)) > 0) {
        publications_received <- bind_rows(
            tibble::as_tibble(compact(
              create_data$review$literature$additional_references)),
            tibble::as_tibble(compact(
              create_data$review$literature$gene_review)),
            .id = "publication_type") %>%
          dplyr::select(publication_id = value, publication_type) %>%
          mutate(publication_type = case_when(
            publication_type == 1 ~ "additional_references",
            publication_type == 2 ~ "gene_review"
          )) %>%
          unique() %>%
          dplyr::select(publication_id, publication_type) %>%
          arrange(publication_id) %>%
          mutate(publication_id = str_replace_all(publication_id,
            "\\s",
            "")) %>%
          rowwise() %>%
          mutate(gr_check = genereviews_from_pmid(publication_id,
            check = TRUE)) %>%
          ungroup() %>%
          mutate(publication_type = case_when(
            publication_type == "additional_references" & gr_check ~
              "gene_review",
            publication_type == "gene_review" & !gr_check ~
              "additional_references",
            TRUE ~ publication_type
          )) %>%
          dplyr::select(-gr_check)

      } else {
        publications_received <- tibble::as_tibble_row(c(publication_id = NA,
          publication_type = NA))
      }

      # convert sysnopsis to tibble, check if comment is null and handle
      if (!is.null(create_data$review$comment)) {
        sysnopsis_received <- tibble::as_tibble(create_data$review$synopsis) %>%
          add_column(response_entity$entry$entity_id) %>%
          add_column(create_data$review$comment) %>%
          add_column(review_user_id) %>%
          dplyr::select(entity_id = `response_entity$entry$entity_id`,
            synopsis = value,
            review_user_id,
            comment = `create_data$review$comment`)
      } else {
        sysnopsis_received <- tibble::as_tibble(create_data$review$synopsis) %>%
          add_column(response_entity$entry$entity_id) %>%
          add_column(review_user_id) %>%
          dplyr::select(entity_id = `response_entity$entry$entity_id`,
            synopsis = value,
            review_user_id,
            comment = NULL)
      }

      # convert phenotypes to tibble
      phenotypes_received <- tibble::as_tibble(create_data$review$phenotypes)

      # convert variation ontology to tibble
      variation_ontology_received <- tibble::as_tibble(
        create_data$review$variation_ontology)

      ##-------------------------------------------------------------------##

      ##-------------------------------------------------------------------##
      # use the "put_post_db_review" function to add
      # the review to the database table and receive a review_id
      response_review <- put_post_db_review(
        "POST",
        sysnopsis_received)

      # only submit publications if not empty
      if (length(compact(create_data$review$literature)) > 0) {
        # use the "new_publication function" to update the publications table
        response_publication <- new_publication(publications_received)

        # make the publication to review connections
        # using the function "put_post_db_pub_con"
        response_publication_conn <- put_post_db_pub_con(
          "POST",
          publications_received,
          as.integer(sysnopsis_received$entity_id),
          as.integer(response_review$entry$review_id))
      } else {
        response_publication <- list(status = 200,
          message = "OK. Skipped.")
        response_publication_conn <- list(status = 200,
          message = "OK. Skipped.")
      }

      # only submit phenotype connections if not empty
      if (length(compact(create_data$review$phenotypes)) > 0) {
        # make the phenotype to review connections
        # using the function "response_phenotype_connections"
        response_phenotype_connections <- put_post_db_phen_con(
          "POST",
          phenotypes_received,
          as.integer(sysnopsis_received$entity_id),
          as.integer(response_review$entry$review_id))
      } else {
        response_phenotype_connections <- list(status = 200,
          message = "OK. Skipped.")
      }

      # only submit variation ontology connections if not empty
      if (length(compact(create_data$review$variation_ontology)) > 0) {
        # make the variation ontology to review connections
        # using the function "put_post_db_var_ont_con"
        resp_variation_ontology_conn <- put_post_db_var_ont_con(
          "POST",
          variation_ontology_received,
          as.integer(sysnopsis_received$entity_id),
          as.integer(response_review$entry$review_id))
      } else {
        resp_variation_ontology_conn <- list(status = 200,
          message = "OK. Skipped.")
      }

      # im a direct approval is requested call the
      # put_db_review_approve function with the review id
      if (direct_approval) {
        response_review_approve <- put_db_review_approve(
            response_review$entry$review_id,
            review_user_id,
            TRUE)
      }

      # compute aggregated review response
      response_review_post <- tibble::as_tibble(response_publication) %>%
        bind_rows(tibble::as_tibble(response_review)) %>%
        bind_rows(tibble::as_tibble(response_publication_conn)) %>%
        bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
        bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
        dplyr::select(status, message) %>%
        mutate(status = max(status)) %>%
        mutate(message = str_c(message, collapse = "; ")) %>%
        unique()
      ##-------------------------------------------------------------------##
    ##-------------------------------------------------------------------##
    } else {
      res$status <- response_entity$status
      return(list(status = response_entity$status,
        message = response_entity$message,
        error = response_entity$error))
    }


    if (response_entity$status == 200 && response_review_post$status == 200) {
    ##-------------------------------------------------------------------##
    # block to post new status for posted entity
      ##-------------------------------------------------------------------##
      # data preparation
      create_data$status <- tibble::as_tibble(create_data$status) %>%
        add_column(response_entity$entry$entity_id) %>%
        add_column(status_user_id) %>%
        select(entity_id = `response_entity$entry$entity_id`,
          category_id,
          status_user_id,
          comment,
          problematic)
      ##-------------------------------------------------------------------##

      ##-------------------------------------------------------------------##
      # use the put_post_db_status function to
      # add the review to the database table
      create_data$status$status_user_id <- status_user_id

      response_status_post <- put_post_db_status("POST",
        create_data$status)
      ##-------------------------------------------------------------------##

      ##-------------------------------------------------------------------##
      # im a direct approval is requested call the
      # put_db_review_approve function with the review id
      if (direct_approval) {
        response_status_approve <- put_db_status_approve(
            response_status_post$entry,
            status_user_id,
            TRUE)
      }
      ##-------------------------------------------------------------------##

    ##-------------------------------------------------------------------##
    } else {
      response_entity_review_post <- tibble::as_tibble(response_entity) %>%
        bind_rows(tibble::as_tibble(response_review_post)) %>%
        select(status, message) %>%
        unique() %>%
        mutate(status = max(status)) %>%
        mutate(message = str_c(message, collapse = "; "))

      res$status <- response_entity_review_post$status
      return(list(status = response_entity_review_post$status,
        message = response_entity_review_post$message))
    }

    if (response_entity$status == 200 &&
      response_review_post$status == 200 &&
      response_status_post$status == 200) {
      res$status <- response_entity$status
      return(response_entity)
    } else {
      response <- tibble::as_tibble(response_entity) %>%
        bind_rows(tibble::as_tibble(response_review_post)) %>%
        bind_rows(tibble::as_tibble(response_status_post)) %>%
        select(status, message) %>%
        unique() %>%
        mutate(status = max(status)) %>%
        mutate(message = str_c(message, collapse = "; "))

      res$status <- response$status
      return(list(status = response$status, message = response$message))
    }

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Write access forbidden."))
  }
}


#* Renames an entity by updating its disease ontology ID version.
#*
#* # `Details`
#* This endpoint function renames the disease ontology of a entity.
#* It checks user role and replaces the disease_ontology_id_version
#* in the ndd_entity table. It deactivates the old entity_id and sets
#* the replacement using put_db_entity_deactivation. It copies all review
#* information from the old entity to the new one, posts new status for
#* the posted entity, and computes a response based on the status of the requests.
#* If successful, the function returns the new entity_id, otherwise,
#* it returns an error message.
#*
#* # `Input`
#* A JSON object with the following properties:
#* - entity_id: (integer) The ID of the entity to be renamed.
#* - hgnc_id: (string) The HGNC ID of the entity.
#* - hpo_mode_of_inheritance_term: (string) The HPO term for mode of inheritance of the entity.
#* - ndd_phenotype: (string) The non-disease phenotype of the entity.
#* - disease_ontology_id_version: (string) The new version of the disease ontology ID of the entity.
#*
#* # `Return`
#* A JSON object with the following properties:
#* - status: (integer) The HTTP status code of the response.
#* - message: (string) A message describing the outcome of the operation.
#* - entry: (list) A list containing the updated entity ID and other metadata.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param rename_json A JSON object with the above detailed properties.
#*
#* @post /api/entity/rename
function(req, res) {

  # first check rights
  if (req$user_role %in% c("Administrator", "Curator")) {

    new_entry_user_id <- req$user_id

    rename_data <- req$argsBody$rename_json

    ##-------------------------------------------------------------------##
    # get information for submitted old entity_id
    ndd_entity_original <- pool %>%
        tbl("ndd_entity") %>%
        collect() %>%
        filter(entity_id == rename_data$entity$entity_id)

    # replace disease_ontology_id_version in ndd_entity
    # original tibble and deselect entity_id
    ndd_entity_replaced <- ndd_entity_original %>%
        mutate(disease_ontology_id_version =
          rename_data$entity$disease_ontology_id_version) %>%
          mutate(entry_user_id = new_entry_user_id) %>%
        select(-entity_id)
    ##-------------------------------------------------------------------##

    if (rename_data$entity$hgnc_id == ndd_entity_replaced$hgnc_id &&
        rename_data$entity$hpo_mode_of_inheritance_term ==
          ndd_entity_replaced$hpo_mode_of_inheritance_term &&
        rename_data$entity$ndd_phenotype == ndd_entity_replaced$ndd_phenotype &&
        rename_data$entity$disease_ontology_id_version !=
          ndd_entity_original$disease_ontology_id_version) {

        ##-------------------------------------------------------------------##
        # block to post new entity using post_db_entity function
        # this returns the new entity_id
        response_new_entity <- post_db_entity(ndd_entity_replaced)
        ##-------------------------------------------------------------------##

        ##-------------------------------------------------------------------##
        # deactivate the old entity_id and set replacement using
        # the put_db_entity_deactivation function
        response_deactivate <- put_db_entity_deactivation(
          ndd_entity_original$entity_id,
          response_new_entity$entry$entity_id)
        ##-------------------------------------------------------------------##

        ##-------------------------------------------------------------------##
        # block to copy all review info from old entity to new one
        # get the original review data for the submitted old entity_id
        ndd_entity_review_original <- pool %>%
            tbl("ndd_entity_review") %>%
            collect() %>%
            filter(entity_id == rename_data$entity$entity_id, is_primary == 1)

        # replace entity_id in ndd_entity_status_original tibble
        ndd_entity_review_replaced <- ndd_entity_review_original %>%
          mutate(entity_id = response_new_entity$entry$entity_id) %>%
          select(-review_id)

        # get all connections for review
        review_publication_join_ori <- pool %>%
            tbl("ndd_review_publication_join") %>%
            collect() %>%
            filter(review_id == ndd_entity_review_original$review_id) %>%
            select(publication_id, publication_type)

        review_phenotype_connect_ori <- pool %>%
            tbl("ndd_review_phenotype_connect") %>%
            collect() %>%
            filter(review_id == ndd_entity_review_original$review_id) %>%
            select(phenotype_id, modifier_id)

        review_variation_ontology_conn_ori <- pool %>%
            tbl("ndd_review_variation_ontology_connect") %>%
            collect() %>%
            filter(review_id == ndd_entity_review_original$review_id) %>%
            select(vario_id, modifier_id)

        # use the "put_post_db_review" function to add the
        # review to the database table with the new entity_id and receive
        # a review_id for subsequent connection settings
        response_review <- put_post_db_review(
          "POST",
          ndd_entity_review_replaced)

        # only submit publication connections if not empty
        if (length(compact(review_publication_join_ori)) > 0) {
          # make the publication to review connections
          # using the function "put_post_db_pub_con"
          response_publication_conn <- put_post_db_pub_con(
            "POST",
            review_publication_join_ori,
            as.integer(response_new_entity$entry$entity_id),
            as.integer(response_review$entry$review_id))
        } else {
          response_publication_conn <- list(status = 200,
            message = "OK. Skipped.")
        }

        # only submit phenotype connections if not empty
        if (length(compact(review_phenotype_connect_ori)) > 0) {
          # make the phenotype to review connections
          # using the function "response_phenotype_connections"
          response_phenotype_connections <- put_post_db_phen_con(
            "POST",
            review_phenotype_connect_ori,
            as.integer(response_new_entity$entry$entity_id),
            as.integer(response_review$entry$review_id))
        } else {
          response_phenotype_connections <- list(status = 200,
            message = "OK. Skipped.")
        }

        # only submit variation ontology connections if not empty
        if (length(compact(review_variation_ontology_conn_ori)) > 0) {
          # make the variation ontology to review connections
          # using the function "put_post_db_var_ont_con"
          resp_variation_ontology_conn <- put_post_db_var_ont_con(
            "POST",
            review_variation_ontology_conn_ori,
            as.integer(response_new_entity$entry$entity_id),
            as.integer(response_review$entry$review_id))
        } else {
          resp_variation_ontology_conn <- list(status = 200,
            message = "OK. Skipped.")
        }

        # compute aggregated review response
        response_review_post <- tibble::as_tibble(response_review) %>%
          bind_rows(tibble::as_tibble(response_publication_conn)) %>%
          bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
          bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
          select(status, message) %>%
          unique() %>%
          mutate(status = max(status)) %>%
          mutate(message = str_c(message, collapse = "; "))
        ##-------------------------------------------------------------------##

        ##-------------------------------------------------------------------##
        # block to post new status for posted entity
        # get the original status data for the submitted old entity_id
        ndd_entity_status_original <- pool %>%
          tbl("ndd_entity_status") %>%
          collect() %>%
          filter(entity_id == rename_data$entity$entity_id, is_active == 1)

        # replace entity_id in ndd_entity_status_original tibble
        ndd_entity_status_replaced <- ndd_entity_status_original %>%
          mutate(entity_id = response_new_entity$entry$entity_id) %>%
          select(-status_id)

        # use the put_post_db_status function to
        # add the status to the database table
        response_status_post <- put_post_db_status("POST",
          ndd_entity_status_replaced)
        ##-------------------------------------------------------------------##

        ##-------------------------------------------------------------------##
        # block to compute response
        if (response_new_entity$status == 200 &&
        response_review_post$status == 200 &&
        response_status_post$status == 200) {
        res$status <- response_new_entity$status
        return(response_new_entity)
        } else {
        response <- tibble::as_tibble(response_new_entity) %>%
            bind_rows(tibble::as_tibble(response_review_post)) %>%
            bind_rows(tibble::as_tibble(response_status_post)) %>%
            select(status, message) %>%
            unique() %>%
            mutate(status = max(status)) %>%
            mutate(message = str_c(message, collapse = "; "))

        res$status <- response$status
        return(list(status = response$status,
           message = response$message))
        }
        ##-------------------------------------------------------------------##

    } else {
      res$status <- 400 # Bad Request
      return(list(error = paste0("This endpoint only allows renaming",
          " the disease ontology of an entity.")
        )
      )
    }

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Write access forbidden."))
  }
}


#* Deactivate Entity
#*
#* This endpoint allows for the deactivation of an existing entity.
#* The function checks user rights and proceeds with the deactivation
#* only if the user role is either Administrator or Curator.
#* The deactivation process includes updating the 'is_active' and 'replaced_by'
#* fields in the database.
#*
#* # `Details`
#* The function only allows deactivation of an entity, any other
#* changes to the entity will result in a 'Bad Request' response.
#*
#* # `Return`
#* A list with status and message of the operation or an error
#* message if user has no write access or if the request is invalid.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @response 200 OK. A list with status, message and entity_id.
#* @response 400 Bad Request. Submitted JSON data does not match the criteria for deactivating or is malformed.
#* @response 403 Forbidden. User does not have the required role.
#* @response 500 Internal server error.
#*
#* @post /api/entity/deactivate
function(req, res) {
  # first check rights
  if (req$user_role %in% c("Administrator", "Curator")) {

    deactivate_user_id <- req$user_id

    deactivate_data <- req$argsBody$deactivate_json

    ##-------------------------------------------------------------------##
    # get information for submitted old entity_id
    ndd_entity_original <- pool %>%
        tbl("ndd_entity") %>%
        collect() %>%
        filter(entity_id == deactivate_data$entity$entity_id)

    # replace is_active and replaced_by in ndd_entity
    # original tibble and select entity_id
    ndd_entity_replaced <- ndd_entity_original %>%
        mutate(is_active =
          deactivate_data$entity$is_active) %>%
        mutate(replaced_by =
          deactivate_data$entity$replaced_by)
    ##-------------------------------------------------------------------##

    if (deactivate_data$entity$hgnc_id == ndd_entity_replaced$hgnc_id &&
        deactivate_data$entity$hpo_mode_of_inheritance_term ==
          ndd_entity_replaced$hpo_mode_of_inheritance_term &&
        deactivate_data$entity$ndd_phenotype ==
          ndd_entity_replaced$ndd_phenotype &&
        deactivate_data$entity$is_active !=
          ndd_entity_original$is_active) {

        ##-------------------------------------------------------------------##
        # block to deactivate the entity using
        # put_db_entity_deactivation function
        response_new_entity <- put_db_entity_deactivation(
          deactivate_data$entity$entity_id,
          ndd_entity_replaced$replaced_by)
        ##-------------------------------------------------------------------##


        ##-------------------------------------------------------------------##
        # block to compute response
        res$status <- response_new_entity$status
        return(list(status = response_new_entity$status,
          message = response_new_entity$message))
        ##-------------------------------------------------------------------##

    } else {
      res$status <- 400 # Bad Request
      return(list(error = "This endpoint only allows deactivating an entity."))
    }

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Write access forbidden."))
  }
}


#* Get Phenotypes for Entity
#*
#* This endpoint retrieves all phenotypes associated with a
#* given entity_id. The function gets data from the database, performs
#* necessary joins and filtering to produce the list of phenotypes.
#*
#* # `Details`
#* The function joins active entities with phenotype connections
#* and then matches these with the phenotype list to get a complete
#* phenotype information for the given entity_id.
#*
#* # `Return`
#* A dataframe containing entity_id, phenotype_id, HPO_term,
#* and modifier_id for each phenotype associated with the entity_id.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id A numeric, representing the entity_id to be retrieved.
#*
#* @response 200 OK. A data frame as described above.
#* @response 500 Internal server error.
#*
#* @get /api/entity/<sysndd_id>/phenotypes
function(sysndd_id) {

  # get data from database and filter
  ndd_review_phenotype_conn_coll <- pool %>%
    tbl("ndd_review_phenotype_connect") %>%
    filter(is_active == 1) %>%
    collect()

  phenotype_list_collected <- pool %>%
    tbl("phenotype_list") %>%
    collect()

  ndd_entity_active <- pool %>%
    tbl("ndd_entity_view") %>%
    select(entity_id) %>%
    collect()

  phenotype_list <- ndd_entity_active %>%
    left_join(ndd_review_phenotype_conn_coll, by = c("entity_id")) %>%
    filter(entity_id == sysndd_id) %>%
    inner_join(phenotype_list_collected, by = c("phenotype_id")) %>%
    select(entity_id, phenotype_id, HPO_term, modifier_id) %>%
    arrange(phenotype_id) %>%
    unique()
}


#* Get Variation Ontology for Entity
#*
#* This endpoint retrieves all variation ontology terms associated
#* with a given entity_id. The function fetches data from the database,
#* performs necessary joins and filtering to produce the
#* list of variation ontology terms.
#*
#* # `Details`
#*The function first collects the active variation ontology connections
#* from the database, then filters for the given entity_id,
#* and joins these with the variation ontology list to get the complete
#* variation ontology information.
#*
#* # `Return`
#* A dataframe containing entity_id, vario_id, vario_name, and
#* modifier_id for each variation ontology term associated with the entity_id.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id The entity_id for which ontology should be retrieved.
#*
#* @get /api/entity/<sysndd_id>/variation
function(sysndd_id) {

  # get data from database and filter
  ndd_review_variation_conn_coll <- pool %>%
    tbl("ndd_review_variation_ontology_connect") %>%
    filter(is_active == 1) %>%
    collect()
  variation_list_collected <- pool %>%
    tbl("variation_ontology_list") %>%
    collect()

  variation_list <- ndd_review_variation_conn_coll %>%
    filter(entity_id == sysndd_id) %>%
    inner_join(variation_list_collected, by = c("vario_id")) %>%
    select(entity_id, vario_id, vario_name, modifier_id) %>%
    arrange(vario_id) %>%
    unique()
}


#* Get Clinical Synopsis for Entity
#*
#* This endpoint retrieves all clinical synopsis associated with a
#* given entity_id. The function fetches data from the database, performs
#* necessary filtering to produce the list of clinical synopsis.
#*
#* # `Details`
#* The function collects the review data from the database, filters for
#* the given entity_id and primary reviews, and selects necessary columns. The
#* result is then joined with the provided entity_id to provide a complete list.
#*
#* # `Return`
#* A dataframe containing entity_id, review_id, synopsis,
#* review_date, and comment for each clinical synopsis associated
#* with the entity_id.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id The entity_id for which the clinical synopsis is to be retrieved.
#*
#* @get /api/entity/<sysndd_id>/review
function(sysndd_id) {

  # get data from database and filter
  ndd_entity_review_collected <- pool %>%
    tbl("ndd_entity_review") %>%
    collect()

  ndd_entity_review_list <- ndd_entity_review_collected %>%
    filter(entity_id == sysndd_id & is_primary) %>%
    select(entity_id, review_id, synopsis, review_date, comment) %>%
    arrange(review_date)

  ndd_entity_review_list_joined <- tibble::as_tibble(sysndd_id) %>%
    select(entity_id = value) %>%
    mutate(entity_id = as.integer(entity_id)) %>%
    left_join(ndd_entity_review_list, by = c("entity_id"))
}


#* Get Entity Status
#*
#* This endpoint retrieves the status for a given entity_id. The
#* function collects the status data from the database, performs necessary
#* filtering, and joins with the status categories list.
#*
#* # `Details`
#* The function fetches status data and status categories from the
#* database, filters for the given entity_id and active status, joins with the
#* categories list, and selects relevant columns. The result is then ordered
#* by status date.
#*
#* # `Return`
#* A dataframe containing status_id, entity_id, category, category_id,
#* status_date, comment, and problematic fields for the status associated with
#* the entity_id.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id The entity_id for which the status is to be retrieved.
#*
#* @get /api/entity/<sysndd_id>/status
function(sysndd_id) {

  # get data from database and filter
  ndd_entity_status_collected <- pool %>%
    tbl("ndd_entity_status") %>%
    collect()

  entity_status_categories_coll <- pool %>%
    tbl("ndd_entity_status_categories_list") %>%
    collect()

  ndd_entity_status_list <- ndd_entity_status_collected %>%
    filter(entity_id == sysndd_id & is_active) %>%
    inner_join(entity_status_categories_coll, by = c("category_id")) %>%
    select(status_id,
      entity_id,
      category,
      category_id,
      status_date,
      comment,
      problematic) %>%
    arrange(status_date)
}


#* Get Entity Publications
#*
#* This endpoint retrieves all publications associated with a
#* given entity_id. It collects publication data from the database, performs
#* necessary filtering and joins, and selects relevant fields.
#*
#* # `Details`
#* The function fetches publication data and entity data from the
#* database, filters for reviewed publications and the given entity_id, joins
#* on entity_id, and selects relevant columns. The result is then ordered by
#* publication_id and de-duplicated.
#*
#* # `Return`
#* A dataframe containing entity_id, publication_id, publication_type,
#* and is_reviewed fields for the publications associated with the entity_id.
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sysndd_id The entity_id for which the publications are to be retrieved.
#*
#* @get /api/entity/<sysndd_id>/publications
function(sysndd_id) {

  # get data from database and filter
  review_publication_join_coll <- pool %>%
    tbl("ndd_review_publication_join") %>%
    filter(is_reviewed == 1) %>%
    collect()

  ndd_entity_active <- pool %>%
    tbl("ndd_entity_view") %>%
    select(entity_id) %>%
    collect()

  ndd_entity_publication_list <- ndd_entity_active %>%
    left_join(review_publication_join_coll, by = c("entity_id")) %>%
    filter(entity_id == sysndd_id) %>%
    select(entity_id, publication_id, publication_type, is_reviewed) %>%
    arrange(publication_id) %>%
    unique()
}

## Entity endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Review endpoints

#* Get Review List
#*
#* This endpoint is responsible for getting the list of reviews. It accepts a
#* filter parameter to display only approved reviews. The function fetches
#* review data from multiple database tables, applies filters, and returns the
#* review list.
#*
#* # `Details`
#* This is a Plumber endpoint function that handles fetching review data from
#* the database. The function pulls data from multiple tables including user,
#* gene, disease, inheritance mode, approval status, and other related
#* information. The function applies a filter based on the 'filter_review_
#* approved' parameter and returns the filtered review list.
#*
#* # `Return`
#* The function returns a list of reviews that match the applied filter. Each
#* review includes the review ID, entity ID, gene details, disease details,
#* inheritance mode, review details, approval details, and status information.
#*
#* @tag review
#* @serializer json list(na="null")
#*
#* @param filter_review_approved: A boolean indicating whether to filter
#*             reviews based on approval status. If TRUE, only approved reviews
#*             are returned. If FALSE or not provided, all reviews are returned.
#*
#* @response 200 OK. A list of reviews that match the applied filter.
#*
#* @get /api/review
function(req, res, filter_review_approved = FALSE) {

  # TODO: maybe this endpoint should be authenticated
  # TODO: implement server side pagination, sorting etc.
  # make sure filter_review_approved input is logical
  filter_review_approved <- as.logical(filter_review_approved)

  # get data from database and filter
  # user information from user table
  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, user_name, user_role)
  # gene information from non_alt_loci_set table
  non_alt_loci_set <- pool %>%
    tbl("non_alt_loci_set") %>%
    select(hgnc_id, symbol)
  # disease information from disease_ontology_set table
  disease_ontology_set <- pool %>%
    tbl("disease_ontology_set") %>%
    select(disease_ontology_id,
      disease_ontology_id_version,
      disease_ontology_name)
  # moi information from mode_of_inheritance_list table
  mode_of_inheritance_list <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    select(-is_active, -sort)
  # approved status from ndd_entity_status_approved_view view
  ndd_entity_status_approved_view <- pool %>%
    tbl("ndd_entity_status_approved_view") %>%
    select(entity_id, status_approved, category_id)
  # categories status from ndd_entity_status_categories_list table
  ndd_entity_status_categories_list <- pool %>%
    tbl("ndd_entity_status_categories_list")
  # boolean values from boolean_list table
  boolean_list <- pool %>%
    tbl("boolean_list")

  # generate entity table with human readable information
  # TODO replace with entity_view (then filtered in other EPs)
  ndd_entity_tbl <- pool %>%
    tbl("ndd_entity") %>%
    left_join(non_alt_loci_set,
      by = c("hgnc_id")) %>%
    left_join(disease_ontology_set,
      by = c("disease_ontology_id_version")) %>%
    left_join(mode_of_inheritance_list,
      by = c("hpo_mode_of_inheritance_term")) %>%
    left_join(ndd_entity_status_approved_view,
      by = c("entity_id")) %>%
    left_join(ndd_entity_status_categories_list,
      by = c("category_id")) %>%
    left_join(boolean_list,
      by = c("ndd_phenotype" = "logical")) %>%
    select(entity_id,
      hgnc_id,
      symbol,
      disease_ontology_id_version,
      disease_ontology_name,
      hpo_mode_of_inheritance_term,
      hpo_mode_of_inheritance_term_name)

  # join the table and apply filters
  review_table_collected <- pool %>%
    tbl("ndd_entity_review") %>%
    left_join(user_table, by = c("review_user_id" = "user_id")) %>%
    left_join(user_table, by = c("approving_user_id" = "user_id")) %>%
    left_join(ndd_entity_tbl, by = c("entity_id")) %>%
    filter(review_approved == filter_review_approved) %>%
    collect() %>%
    select(review_id,
      entity_id,
      hgnc_id,
      symbol,
      disease_ontology_id_version,
      disease_ontology_name,
      hpo_mode_of_inheritance_term,
      hpo_mode_of_inheritance_term_name,
      synopsis,
      is_primary,
      review_date,
      review_user_name = user_name.x,
      review_user_role = user_role.x,
      review_approved,
      approving_user_name = user_name.y,
      approving_user_role = user_role.y,
      approving_user_id,
      comment) %>%
    arrange(entity_id, review_date) %>%
    # check if duplicate values exist
    group_by(entity_id) %>%
    mutate(duplicate = n()) %>%
    mutate(duplicate = case_when(
      duplicate == 1 ~ "no",
      TRUE ~ "yes"
    )) %>%
    ungroup()

  # compute status table
  status_table <- pool %>%
      tbl("ndd_entity_status") %>%
      collect() %>%
      filter(entity_id %in% review_table_collected$entity_id) %>%
      select(entity_id, status_id, category_id, is_active, status_date) %>%
      arrange(entity_id) %>%
      group_by(entity_id) %>%
      mutate(active_status = case_when(
              is_active == max(is_active) ~ status_id
          ), active_category = case_when(
              is_active == max(is_active) ~ category_id
          )
      ) %>%
      mutate(newest_status = case_when(
              status_date == max(status_date) ~ status_id
          ), newest_category = case_when(
              status_date == max(status_date) ~ category_id
          )
      ) %>%
      select(entity_id,
        active_status,
        active_category,
        newest_status,
        newest_category) %>%
      mutate(active_status = max(active_status, na.rm = TRUE),
          active_category = max(active_category, na.rm = TRUE),
          newest_status = max(newest_status, na.rm = TRUE),
          newest_category = max(newest_category, na.rm = TRUE),
      ) %>%
      ungroup() %>%
      unique() %>%
      mutate(status_change = as.numeric(!(active_status == newest_status)))

  review_table_collected <- review_table_collected %>%
    left_join(status_table, by = c("entity_id"))

  review_table_collected
}

#* Create or Update a Clinical Synopsis for an Entity ID
#*
#* This endpoint handles creating or updating a clinical synopsis for a
#* specified entity ID. The function checks the user role and accepts a review
#* JSON. It validates the JSON data and performs database operations accordingly.
#* Depending on the request type (POST or PUT), the function creates a new
#* review or updates an existing one, and links the review with publications,
#* phenotypes, and variation ontology.
#*
#* # `Details`
#* This is a Plumber endpoint function that handles creating or updating
#* clinical synopsis for an entity ID. The function first checks the user role
#* and then validates the submitted review data. Depending on the request type
#* (POST or PUT), the function creates a new review or updates an existing one,
#* and links the review with publications, phenotypes, and variation ontology.
#* It also handles re-reviewing scenarios.
#*
#* # `Return`
#* The function returns a response containing the status and message. The
#* message provides information about the operations performed during the
#* request handling.
#*
#* @tag review
#* @serializer json list(na="string")
#*
#* @param re_review: A boolean indicating whether to re-review an existing
#*             review. If TRUE, the function will handle re-reviewing scenarios.
#*
#* @response 200 OK. The operation was successful.
#* @response 400 Bad Request. The submitted synopsis data cannot be empty.
#* @response 403 Forbidden. The user does not have write access.
#* @response 405 Method Not Allowed. The HTTP method used is not allowed.
#*
#* @post /api/review/create
#* @put /api/review/update
function(req, res, re_review = FALSE) {

  # first check rights
  if (req$user_role %in% c("Administrator", "Curator", "Reviewer")) {
    # make sure re_review input is logical
    re_review <- as.logical(re_review)

    review_user_id <- req$user_id
    review_data <- req$argsBody$review_json

    if (!is.null(review_data$synopsis) &&
      !is.null(review_data$entity_id) &&
      nchar(review_data$synopsis) > 0) {

      ##-------------------------------------------------------------------##
      # convert publications to tibble
      if (length(compact(review_data$literature)) > 0) {
        publications_received <- bind_rows(
            tibble::as_tibble(
              compact(review_data$literature$additional_references)),
            tibble::as_tibble(
              compact(review_data$literature$gene_review)),
            .id = "publication_type") %>%
          select(publication_id = value, publication_type) %>%
          mutate(publication_type = case_when(
            publication_type == 1 ~ "additional_references",
            publication_type == 2 ~ "gene_review"
          )) %>%
          unique() %>%
          select(publication_id, publication_type) %>%
          arrange(publication_id) %>%
          mutate(publication_id = str_replace_all(publication_id,
            "\\s",
            "")) %>%
          rowwise() %>%
          mutate(gr_check =
            genereviews_from_pmid(publication_id,
              check = TRUE)
          ) %>%
          ungroup() %>%
          mutate(publication_type = case_when(
            publication_type == "additional_references" & gr_check ~
              "gene_review",
            publication_type == "gene_review" & !gr_check ~
              "additional_references",
            TRUE ~ publication_type
          )) %>%
          select(-gr_check)
      } else {
        publications_received <- tibble::as_tibble_row(c(publication_id = NA,
          publication_type = NA))
      }

      # convert sysnopsis to tibble, check if comment is null and handle
      # NULL value is replaced with empty string for downward compatibility
      if (!is.null(review_data$comment)) {
        sysnopsis_received <- tibble::as_tibble(review_data$synopsis) %>%
          add_column(review_data$entity_id) %>%
          add_column(review_data$comment) %>%
          add_column(review_user_id) %>%
          select(entity_id = `review_data$entity_id`,
            synopsis = value,
            review_user_id,
            comment = `review_data$comment`)
      } else {
        sysnopsis_received <- tibble::as_tibble(review_data$synopsis) %>%
          add_column(review_data$entity_id) %>%
          add_column(review_user_id) %>%
          select(entity_id = `review_data$entity_id`,
            synopsis = value,
            review_user_id,
            comment = NULL)
      }

      # convert phenotypes to tibble
      phenotypes_received <- tibble::as_tibble(review_data$phenotypes)

      # convert variation ontology to tibble
      variation_received <- tibble::as_tibble(review_data$variation_ontology)

      ##-------------------------------------------------------------------##


      ##-------------------------------------------------------------------##
      # check request type and perform database update accordingly
      if (req$REQUEST_METHOD == "POST") {
        ##-------------------------------------------------------------------##
        # use the "put_post_db_review" function to add the
        # review to the database table and receive an review_id
        response_review <- put_post_db_review(
          req$REQUEST_METHOD,
          sysnopsis_received,
          re_review)

        # only submit publications if not empty
        if (length(compact(review_data$literature)) > 0) {
          # use the "new_publication function" to update the publications table
          response_publication <- new_publication(publications_received)

          # make the publication to review connections using the
          # function "put_post_db_pub_con"
          response_publication_conn <- put_post_db_pub_con(
            req$REQUEST_METHOD,
            publications_received,
            as.integer(sysnopsis_received$entity_id),
            as.integer(response_review$entry$review_id))
        } else {
          response_publication <- list(status = 200, message = "OK. Skipped.")
          response_publication_conn <- list(status = 200,
            message = "OK. Skipped.")
        }

        # only submit phenotype connections if not empty
        if (length(compact(phenotypes_received)) > 0) {
          # make the phenotype to review connections using the
          # function "put_post_db_phen_con"
          response_phenotype_connections <- put_post_db_phen_con(
            req$REQUEST_METHOD,
            phenotypes_received,
            as.integer(sysnopsis_received$entity_id),
            as.integer(response_review$entry$review_id))
        } else {
          response_phenotype_connections <- list(status = 200,
            message = "OK. Skipped.")
        }

        # only submit variation ontology connections if not empty
        if (length(compact(variation_received)) > 0) {
          # make the variation ontology to review connections
          # using the function "put_post_db_var_ont_con"
          resp_variation_ontology_conn <- put_post_db_var_ont_con(
            req$REQUEST_METHOD,
            variation_received,
            as.integer(sysnopsis_received$entity_id),
            as.integer(response_review$entry$review_id))
        } else {
          resp_variation_ontology_conn <- list(status = 200,
            message = "OK. Skipped.")
        }

        # compute response
        response <- tibble::as_tibble(response_publication) %>%
          bind_rows(tibble::as_tibble(response_review)) %>%
          bind_rows(tibble::as_tibble(response_publication_conn)) %>%
          bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
          bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
          select(status, message) %>%
          unique() %>%
          mutate(status = max(status)) %>%
          mutate(message = str_c(message, collapse = "; "))

        # return aggregated response
        return(list(status = response$status, message = response$message))
        ##-------------------------------------------------------------------##
      } else if (req$REQUEST_METHOD == "PUT") {
        ##-------------------------------------------------------------------##

        # first add the review_id from the received
        # review_data to the sysnopsis_received tibble
        sysnopsis_received$review_id <- review_data$review_id

        # then use the "put_post_db_review" function to add the
        # review to the database table and receive an review_id
        response_review <- put_post_db_review(
            req$REQUEST_METHOD,
            sysnopsis_received,
            re_review)

        # only submit publications if not empty
        if (length(compact(review_data$literature)) > 0) {
          # use the "new_publication function" to update the publications table
          response_publication <- new_publication(publications_received)

        # make the publication to review connections using
        # the function "put_post_db_pub_con"
        response_publication_conn <- put_post_db_pub_con(
          req$REQUEST_METHOD,
          publications_received,
          sysnopsis_received$entity_id,
          review_data$review_id)

        } else {
          response_publication <- list(status = 200,
            message = "OK. Skipped.")
          response_publication_conn <- list(status = 200,
            message = "OK. Skipped.")
        }

        # only submit phenotype connections if not empty
        if (length(compact(phenotypes_received)) > 0) {
          # make the phenotype to review connections using
          # the function "response_phenotype_connections"
          response_phenotype_connections <- put_post_db_phen_con(
            req$REQUEST_METHOD,
            phenotypes_received,
            as.integer(sysnopsis_received$entity_id),
            as.integer(review_data$review_id))
        } else {
          response_phenotype_connections <- list(status = 200,
            message = "OK. Skipped.")
        }

        # only submit variation ontology connections if not empty
        if (length(compact(variation_received)) > 0) {
          # make the variation ontology to review connections
          # using the function "put_post_db_var_ont_con"
          resp_variation_ontology_conn <- put_post_db_var_ont_con(
            req$REQUEST_METHOD,
            variation_received,
            as.integer(sysnopsis_received$entity_id),
            as.integer(review_data$review_id))
        } else {
          resp_variation_ontology_conn <- list(status = 200,
            message = "OK. Skipped.")
        }

        # compute response
        response <- tibble::as_tibble(response_publication) %>%
          bind_rows(tibble::as_tibble(response_review)) %>%
          bind_rows(tibble::as_tibble(response_publication_conn)) %>%
          bind_rows(tibble::as_tibble(response_phenotype_connections)) %>%
          bind_rows(tibble::as_tibble(resp_variation_ontology_conn)) %>%
          select(status, message) %>%
          unique() %>%
          mutate(status = max(status)) %>%
          mutate(message = str_c(message, collapse = "; "))

        # return aggregated response
        return(list(status = response$status, message = response$message))
        ##-------------------------------------------------------------------##
      } else {
        # return Method Not Allowed
        return(list(status = 405, message = "Method Not Allowed."))
      }
      ##-------------------------------------------------------------------##

    } else {
      res$status <- 400 # Bad Request
      return(list(error = "Submitted synopsis data can not be empty."))
    }

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Write access forbidden."))
  }
}


#* Get a Single Review by review_id
#*
#* This endpoint retrieves a single review by its review_id. The function 
#* accepts a review_id as a parameter, performs data cleaning, and fetches 
#* the corresponding review data from the database.
#*
#* # `Details`
#* This is a Plumber endpoint function that retrieves a single review by its 
#* review_id. The function accepts a review_id, removes spaces from it, and 
#* queries the database to fetch the corresponding review data.
#*
#* # `Return`
#* The function returns a collected review table containing the review details.
#*
#* @tag review
#* @serializer json list(na="null")
#*
#* @param review_id_requested: The review_id of the review to retrieve.
#*
#* @response 200 OK. The operation was successful and the review data is 
#*             returned.
#*
#* @get /api/review/<review_id_requested>
function(review_id_requested) {
  # remove spaces from list
  review_id_requested <- URLdecode(review_id_requested) %>%
    str_split(pattern = ",", simplify = TRUE) %>%
    str_replace_all(" ", "") %>%
    unique()

  # get data from database and filter
  sysndd_db_review_table <- pool %>%
    tbl("ndd_entity_review")

  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, user_name, user_role)

  review_table_collected <- sysndd_db_review_table %>%
    filter(review_id == review_id_requested) %>%
    left_join(user_table, by = c("review_user_id" = "user_id")) %>%
    left_join(user_table, by = c("approving_user_id" = "user_id")) %>%
    collect() %>%
    select(review_id,
      entity_id,
      synopsis,
      is_primary,
      review_date,
      review_user_name = user_name.x,
      review_user_role = user_role.x,
      review_approved,
      approving_user_name = user_name.y,
      approving_user_role = user_role.y,
      comment)

  review_table_collected
}


#* Get All Phenotypes for a Review
#*
#* This endpoint retrieves all phenotypes associated with a review. The function 
#* accepts a review_id as a parameter, performs data cleaning, and fetches 
#* the corresponding phenotype data from the database.
#*
#* # `Details`
#* This is a Plumber endpoint function that retrieves all phenotypes 
#* associated with a specific review. The function accepts a review_id, 
#* removes spaces from it, and queries the database to fetch the corresponding 
#* phenotype data.
#*
#* # `Return`
#* The function returns a list of phenotypes associated with the review.
#*
#* @tag review
#* @serializer json list(na="string")
#*
#* @param review_id_requested: The review_id of the review for which to 
#*                             retrieve phenotypes.
#*
#* @response 200 OK. The operation was successful and the phenotype data 
#*             is returned.
#*
#* @get /api/review/<review_id_requested>/phenotypes
function(review_id_requested) {
  # remove spaces from list
  review_id_requested <- URLdecode(review_id_requested) %>%
    str_split(pattern = ",", simplify = TRUE) %>%
    str_replace_all(" ", "") %>%
    unique()

  # get data from database and filter
  ndd_review_phenotype_conn_coll <- pool %>%
    tbl("ndd_review_phenotype_connect") %>%
    collect()

  phenotype_list_collected <- pool %>%
    tbl("phenotype_list") %>%
    collect()

  phenotype_list <- ndd_review_phenotype_conn_coll %>%
    filter(review_id == review_id_requested & is_active) %>%
    inner_join(phenotype_list_collected, by = c("phenotype_id")) %>%
    select(review_id, entity_id, phenotype_id, HPO_term, modifier_id) %>%
    arrange(phenotype_id)
}


#* Get All Variant Ontology Terms for a Review
#*
#* This endpoint retrieves all variant ontology terms associated with a review. 
#* The function accepts a review_id as a parameter, performs data cleaning, 
#* and fetches the corresponding variant ontology data from the database.
#*
#* # `Details`
#* This is a Plumber endpoint function that retrieves all variant ontology 
#* terms associated with a specific review. The function accepts a review_id, 
#* removes spaces from it, and queries the database to fetch the corresponding 
#* variant ontology data.
#*
#* # `Return`
#* The function returns a list of variant ontology terms associated with the 
#* review.
#*
#* @tag review
#* @serializer json list(na="string")
#*
#* @param review_id_requested: The review_id of the review for which to 
#*                             retrieve variant ontology terms.
#*
#* @response 200 OK. The operation was successful and the variant ontology 
#*             data is returned.
#*
#* @get /api/review/<review_id_requested>/variation
function(review_id_requested) {
  # remove spaces from list
  review_id_requested <- URLdecode(review_id_requested) %>%
    str_split(pattern = ",", simplify = TRUE) %>%
    str_replace_all(" ", "") %>%
    unique()

  # get data from database and filter
  review_variation_ontology_con <- pool %>%
    tbl("ndd_review_variation_ontology_connect") %>%
    collect()

  variation_ontology_list_col <- pool %>%
    tbl("variation_ontology_list") %>%
    collect()

  variation_list <- review_variation_ontology_con %>%
    filter(review_id == review_id_requested & is_active) %>%
    inner_join(variation_ontology_list_col, by = c("vario_id")) %>%
    select(review_id, entity_id, vario_id, vario_name, modifier_id) %>%
    arrange(vario_id)
}


#* Get All Publications for a Review
#*
#* This endpoint retrieves all publications associated with a review. 
#* The function accepts a review_id as a parameter, performs data cleaning, 
#* and fetches the corresponding publications from the database.
#*
#* # `Details`
#* This is a Plumber endpoint function that retrieves all publications 
#* associated with a specific review. The function accepts a review_id, 
#* removes spaces from it, and queries the database to fetch the corresponding 
#* publications.
#*
#* # `Return`
#* The function returns a list of publications associated with the review.
#*
#* @tag review
#* @serializer json list(na="string")
#*
#* @param review_id_requested: The review_id of the review for which to 
#*                             retrieve publications.
#*
#* @response 200 OK. The operation was successful and the publications data 
#*             is returned.
#*
#* @get /api/review/<review_id_requested>/publications
function(review_id_requested) {
  # remove spaces from list
  review_id_requested <- URLdecode(review_id_requested) %>%
    str_split(pattern = ",", simplify = TRUE) %>%
    str_replace_all(" ", "") %>%
    unique()

  # get data from database and filter
  review_publication_join_coll <- pool %>%
    tbl("ndd_review_publication_join") %>%
    collect()

  publication_collected <- pool %>%
    tbl("publication") %>%
    collect()

  ndd_entity_publication_list <- review_publication_join_coll %>%
    filter(review_id == review_id_requested) %>%
    arrange(publication_id)
}

#* Put the Review Approval
#*
#* This endpoint is used to update the approval status of a review. Only 
#* users with "Administrator" or "Curator" roles can perform this action. 
#* The function accepts a review_id and a review_ok flag (indicating approval 
#* status) as parameters, performs user rights checks, and updates the review 
#* approval in the database accordingly.
#*
#* # `Details`
#* This is a Plumber endpoint function that updates the approval status of 
#* a specific review. The function checks the role of the user making the 
#* request to ensure they have the necessary permissions. It then calls the 
#* "put_db_review_approve" function to update the approval status in the 
#* database.
#*
#* # `Return`
#* The function returns a response with the status of the operation.
#*
#* @tag review
#* @serializer json list(na="string")
#*
#* @param review_id_requested: The review_id of the review to be approved.
#* @param review_ok: Boolean flag indicating the approval status.
#*
#* @response 200 OK. The operation was successful and the approval status 
#*             is updated.
#* @response 401 Unauthorized. The user is not authenticated.
#* @response 403 Forbidden. The user does not have the necessary permissions.
#*
#* @put /api/review/approve/<review_id_requested>
function(req, res, review_id_requested, review_ok = FALSE) {
  review_ok <- as.logical(review_ok)

  # first check rights
  if (length(req$user_id) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (req$user_role %in% c("Administrator", "Curator")) {

    submit_user_id <- req$user_id

    # use the "put_db_review_approve" function to add the
    # approval to the database table
    response_review_approve <- put_db_review_approve(
        review_id_requested,
        submit_user_id,
        review_ok)

    # emit response
    response_review_approve

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Write access forbidden."))
  }
}

## Review endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Re-review endpoints

#* Submit a Re-Review Entry
#*
#* This endpoint allows users with roles (Administrator, Curator, Reviewer) to
#* submit a re-review entry to the database.
#*
#* # `Details`
#* This is a Plumber endpoint accepting submission data for re-review entries.
#* It checks the user role for permissions and updates the database accordingly.
#*
#* # `Return`
#* If successful, it returns a success message or the updated entry. For errors,
#* an appropriate error message is returned.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @response 200 OK. If successful, the updated entry or a message is returned.
#* @response 403 Forbidden. If the user lacks the necessary permissions.
#*
#* @put /api/re_review/submit
function(req, res) {
  # first check rights
  if (req$user_role %in% c("Administrator", "Curator", "Reviewer")) {

    submit_user_id <- req$user_id
    submit_data <- req$argsBody$submit_json

    update_query <- tibble::as_tibble(submit_data) %>%
      select(-re_review_entity_id) %>%
      mutate(row = row_number()) %>%
      pivot_longer(-row) %>%
      mutate(query = paste0(name, "='", value, "'")) %>%
      select(query) %>%
      summarize(query = str_c(query, collapse = ", "))

    # connect to database
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port)

    # execute update query
    dbExecute(sysndd_db,
      paste0("UPDATE re_review_entity_connect SET ",
      update_query,
      " WHERE re_review_entity_id = ",
      submit_data$re_review_entity_id,
      ";"))

    # disconnect from database
    dbDisconnect(sysndd_db)

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Write access forbidden."))
  }
}


#* Unsubmit a Re-Review Entry
#*
#* This endpoint allows users with specific roles (Administrator, Curator) to
#* revert a re-review entry to an un-submitted state in the database.
#*
#* # `Details`
#* This is a Plumber endpoint function that reverts the submission status of a
#* specific re-review entry based on its re_review_id. Only users with the roles
#* of Administrator or Curator can perform this action.
#*
#* # `Return`
#* If successful, a success message is returned. In case of errors, such as
#* unauthorized access, an appropriate error message is returned.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param re_review_id The ID of the re-review entry to be un-submitted.
#*
#* @response 200 OK. If the operation is successful, a success message is returned.
#* @response 401 Unauthorized. If the user is not authenticated or lacks permissions.
#*
#* @put /api/re_review/unsubmit/<re_review_id>
function(req, res, re_review_id) {
  # first check rights
  if (length(req$user_id) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (req$user_role %in% c("Administrator", "Curator")) {

    submit_user_id <- req$user_id
    re_review_id <- as.integer(re_review_id)

    # connect to database
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port)

    # execute update query
    dbExecute(sysndd_db,
      paste0("UPDATE re_review_entity_connect ",
        "SET re_review_submitted = 0 ",
        "WHERE re_review_entity_id = ",
        re_review_id,
        ";"))

    # disconnect from database
    dbDisconnect(sysndd_db)

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Write access forbidden."))
  }
}


#* Approve a Re-Review Entry
#*
#* This endpoint allows users with specific roles (Administrator, Curator) to
#* approve a re-review entry in the database.
#*
#* # `Details`
#* This is a Plumber endpoint function that approves a specific re-review entry
#* based on its re_review_id. Only users with the roles of Administrator or
#* Curator can perform this action.
#*
#* # `Return`
#* If successful, a success message indicating the approval is returned. In case
#* of errors, an appropriate error message is returned.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param re_review_id The ID of the re-review entry to be approved.
#*
#* @response 200 OK. If successful, a success message indicating the approval is
#*             returned.
#* @response 401 Unauthorized. If the user is not authenticated or lacks permissions.
#*
#* @put /api/re_review/approve/<re_review_id>
function(req, res, re_review_id, status_ok = FALSE, review_ok = FALSE) {
  status_ok <- as.logical(status_ok)
  review_ok <- as.logical(review_ok)

  # first check rights
  if (length(req$user_id) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (req$user_role %in% c("Administrator", "Curator")) {

    submit_user_id <- req$user_id
    re_review_id <- as.integer(re_review_id)

    # get table data from database
    re_review_entity_connect_data <- pool %>%
      tbl("re_review_entity_connect") %>%
      filter(re_review_entity_id == re_review_id) %>%
      collect()

    # connect to database
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port)

    # set status if confirmed
    if (status_ok) {
      # reset all status in ndd_entity_status to inactive
      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_status SET is_active = 0 WHERE entity_id = ",
        re_review_entity_connect_data$entity_id,
        ";"))

      # set status of the new status from re_review_entity_connect to active,
      # add approving_user_id and set approved status to approved
      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_status ",
          "SET is_active = 1 ",
          "WHERE status_id = ",
          re_review_entity_connect_data$status_id,
          ";"))

      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_status ",
          "SET approving_user_id = ",
          submit_user_id,
          " WHERE status_id = ",
          re_review_entity_connect_data$status_id,
          ";"))

      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_status ",
          "SET status_approved = 1 ",
          "WHERE status_id = ",
          re_review_entity_connect_data$status_id,
          ";"))
    } else {
      # add approving_user_id and set approved status to unapproved
      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_status ",
          "SET approving_user_id = ",
          submit_user_id,
          " WHERE status_id = ",
          re_review_entity_connect_data$status_id,
          ";"))
      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_status ",
          "SET status_approved = 0 ",
          "WHERE status_id = ",
          re_review_entity_connect_data$status_id,
          ";"))
    }

    # set review if confirmed
    if (review_ok) {
      # reset all reviews in ndd_entity_review to not primary
      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_review ",
          "SET is_primary = 0 ",
          "WHERE entity_id = ",
          re_review_entity_connect_data$entity_id,
          ";"))

      # set the new review from re_review_entity_connect to primary,
      # add approving_user_id and set approved status to approved
      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_review ",
          "SET is_primary = 1 ",
          "WHERE review_id = ",
          re_review_entity_connect_data$review_id,
          ";"))

      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_review ",
          "SET approving_user_id = ",
          submit_user_id,
          " WHERE review_id = ",
          re_review_entity_connect_data$review_id,
          ";"))

      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_review SET ",
          "review_approved = 1 ",
          "WHERE review_id = ",
          re_review_entity_connect_data$review_id,
          ";"))

    } else {
      # add approving_user_id and set approved status to unapproved
      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_review ",
          "SET approving_user_id = ",
          submit_user_id,
          " WHERE review_id = ",
          re_review_entity_connect_data$review_id,
          ";"))
      dbExecute(sysndd_db,
        paste0("UPDATE ndd_entity_review ",
          "SET review_approved = 0 ",
          "WHERE review_id = ",
          re_review_entity_connect_data$review_id,
          ";"))
    }

    # set re_review_approved status to yes and add approving_user_id
    dbExecute(sysndd_db,
      paste0("UPDATE re_review_entity_connect ",
        "SET re_review_approved = 1 ",
        "WHERE re_review_entity_id = ",
        re_review_id,
        ";"))

    dbExecute(sysndd_db,
      paste0("UPDATE re_review_entity_connect ",
        "SET approving_user_id = ",
        submit_user_id,
        " WHERE re_review_entity_id = ",
        re_review_id,
        ";"))

    # disconnect from database
    dbDisconnect(sysndd_db)

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Write access forbidden."))
  }
}


#* Get Re-Review Overview Table
#* 
#* This endpoint returns the re-review overview table for the authenticated user.
#* 
#* # `Details`
#* The function filters the re-review data based on the provided `filter` and
#* `curate` parameters. Users with the roles of Administrator, Curator, or
#* Reviewer can access this endpoint.
#* 
#* # `Return`
#* Returns a re-review overview table if successful, or an error message.
#*
#* @tag re_review
#* @serializer json list(na="string")
#* 
#* @param filter: The filter condition for the re-review data.
#* @param curate: Boolean flag indicating whether to curate the data.
#*
#* @response 200 OK. Returns the re-review overview table.
#* @response 401 Unauthorized. The user is not authenticated.
#* @response 403 Forbidden. The user does not have the necessary permissions.
#*
#* @get /api/re_review_table
function(req,
  res,
  filter = "or(lessOrEqual(review_date,2020-01-01),equals(re_review_review_saved,1)",
  curate = FALSE) {
  curate <- as.logical(curate)

  # generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # first check rights
  if (length(req$user_id) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (
    (req$user_role %in% c("Administrator", "Curator", "Reviewer") && !curate) ||
    (req$user_role %in% c("Administrator", "Curator") && curate)) {

    user <- req$user_id

    # get table data from database and filter
    re_review_entity_connect <- pool %>%
      tbl("re_review_entity_connect") %>%
      filter(re_review_approved == 0) %>%
      {if (curate)
        filter(., re_review_submitted == 1)
      else
        filter(., re_review_submitted == 0)
      }
    re_review_assignment <- pool %>%
      tbl("re_review_assignment") %>%
      {if (!curate)
        filter(., user_id == user)
      else .
      }
    ndd_entity_view <- pool %>%
      tbl("ndd_entity_view")
    ndd_entity_status_category <- pool %>%
      tbl("ndd_entity_status") %>%
      select(status_id, category_id)
    ndd_entity_status_categories_list <- pool %>%
      tbl("ndd_entity_status_categories_list")

  # user information from user table
  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, user_name, user_role)
  # join with ndd_entity_review to get review user info
  review_user_collected <- pool %>%
    tbl("ndd_entity_review") %>%
    left_join(user_table, by = c("review_user_id" = "user_id")) %>%
    select(review_id,
      review_date,
      review_user_id,
      review_user_name = user_name,
      review_user_role = user_role,
      review_approving_user_id = approving_user_id)
  # join with ndd_entity_status to get status user info
  status_user_collected <- pool %>%
    tbl("ndd_entity_status") %>%
    left_join(user_table, by = c("status_user_id" = "user_id")) %>%
    select(status_id,
      status_date,
      status_user_id,
      status_user_name = user_name,
      status_user_role = user_role,
      status_approving_user_id = approving_user_id)

    # join and collect
    re_review_user_list <- re_review_entity_connect %>%
      inner_join(re_review_assignment, by = c("re_review_batch")) %>%
      select(re_review_entity_id,
        entity_id,
        re_review_review_saved,
        re_review_status_saved,
        re_review_submitted,
        status_id,
        review_id) %>%
      inner_join(ndd_entity_view, by = c("entity_id")) %>%
      select(-category_id, -category) %>%
      inner_join(ndd_entity_status_category, by = c("status_id")) %>%
      inner_join(review_user_collected, by = c("review_id")) %>%
      inner_join(status_user_collected, by = c("status_id")) %>%
      collect() %>%
      arrange(entity_id) %>%
      filter(!!!rlang::parse_exprs(filter_exprs))

    re_review_user_list

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Read access forbidden."))
  }
}


#* Request New Re-Review Batch
#*
#* This endpoint allows the authenticated user to request a new batch of entities
#* for re-review by sending a mail to curators.
#*
#* # `Details`
#* The function sends an email to curators to request a new batch for re-review.
#* Users with the roles of Administrator, Curator, or Reviewer can access this
#* endpoint.
#*
#* # `Return`
#* Sends a request email to curators if successful, or returns an error message.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @response 200 OK. Email request successfully sent.
#* @response 401 Unauthorized. The user is not authenticated.
#* @response 403 Forbidden. The user does not have the necessary permissions.
#*
#* @get /api/re_review/batch/apply
function(req, res) {

  user <- req$user_id

  # first check rights
  if (length(user) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (req$user_role %in% c("Administrator", "Curator", "Reviewer")) {

    user_table <- pool %>%
      tbl("user") %>%
      collect()

    user_info <- user_table %>%
      filter(user_id == user) %>%
      select(user_id, user_name, email, orcid)

    curator_mail <- (user_table %>%
      filter(user_role == "Curator"))$email

    res <- send_noreply_email(c("Hello", user_info$user_name, "!<br />",
      "<br />Your request for another **re-review batch** has been send to the curators.",
      "They will review and activate your application shortly. <br /><br />",
      "Requesting user info:",
      user_info %>% kable("html"),
      "<br />",
      "Best wishes, <br />The SysNDD team"),
      "Your re-review batch request from SysNDD.org",
      user_info$email,
      curator_mail)

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Read access forbidden."))
  }
}


#* Assign New Re-Review Batch
#*
#* This endpoint allows administrators or curators to assign a new batch of
#* entities for re-review to a specific user.
#*
#* # `Details`
#* The function assigns a new batch of entities for re-review based on the
#* provided `user_id`. Only administrators or curators can perform this action.
#*
#* # `Return`
#* If successful, updates the assignment table. Otherwise, returns an error.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param user_id: The ID of the user to whom the batch will be assigned.
#*
#* @response 200 OK. Successfully updated the assignment table.
#* @response 401 Unauthorized. The user is not authenticated.
#* @response 403 Forbidden. The user does not have the necessary permissions.
#* @response 409 Conflict. User account does not exist or batch does not exist.
#*
#* @put /api/re_review/batch/assign
function(req, res, user_id) {

  user <- req$user_id
  user_id_assign <- as.integer(user_id)

  #check if user_id_assign exists
  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, approved) %>%
    filter(user_id == user_id_assign) %>%
    collect()
  user_id_assign_exists <- as.logical(length(user_table$user_id))

  # compute next batch
  re_review_assignment <- pool %>%
    tbl("re_review_assignment") %>%
    select(re_review_batch)
  re_review_entity_connect <- pool %>%
    tbl("re_review_entity_connect") %>%
    select(re_review_batch) %>%
    anti_join(re_review_assignment, by = c("re_review_batch")) %>%
    collect() %>%
    unique() %>%
    summarize(re_review_batch = min(re_review_batch))
  re_review_batch_next <- re_review_entity_connect$re_review_batch

  # make tibble to append
  assignment_table <- tibble("user_id" = user_id_assign,
    "re_review_batch" = re_review_batch_next)

  # first check rights
  if (length(user) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))
#* @
  } else if (req$user_role %in% c("Administrator", "Curator") && !user_id_assign_exists) {

    res$status <- 409 # Conflict
    return(list(error = "User account does not exist."))

  } else if (req$user_role %in% c("Administrator", "Curator") && user_id_assign_exists) {

    # connect to database, append assignment table then disconnect
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port)

    dbAppendTable(sysndd_db, "re_review_assignment", assignment_table)
    dbDisconnect(sysndd_db)

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Read access forbidden."))
  }
}


#* Unassign Re-Review Batch
#*
#* This endpoint allows administrators or curators to unassign a re-review batch
#* based on the provided `re_review_batch`.
#*
#* # `Details`
#* The function removes a re-review batch assignment. Access is restricted to
#* administrators and curators.
#*
#* # `Return`
#* If successful, the batch is unassigned and removed from the assignment table.
#* Otherwise, returns an error message.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @param re_review_batch: The ID of the re-review batch to unassign.
#*
#* @response 200 OK. Successfully unassigned the re-review batch.
#* @response 401 Unauthorized. The user is not authenticated.
#* @response 403 Forbidden. The user does not have the necessary permissions.
#* @response 409 Conflict. Batch does not exist.
#*
#* @delete /api/re_review/batch/unassign
function(req, res, re_review_batch) {

  user <- req$user_id
  re_review_batch_unassign <- as.integer(re_review_batch)

  #check if assignment_id_unassign exists
  re_review_assignment_table <- pool %>%
    tbl("re_review_assignment") %>%
    select(re_review_batch) %>%
    filter(re_review_batch == re_review_batch_unassign) %>%
    collect()

  re_review_batch_unassign_ex <- as.logical(
    length(re_review_assignment_table$re_review_batch))

  # first check rights
  if (length(user) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (
    req$user_role %in% c("Administrator", "Curator") &&
    !re_review_batch_unassign_ex) {

    res$status <- 409 # Conflict
    return(list(error = "Batch does not exist."))

  } else if (
    req$user_role %in% c("Administrator", "Curator") &&
    re_review_batch_unassign_ex) {

    # connect to database, delete assignment then disconnect
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port)

    dbExecute(sysndd_db,
      paste0("DELETE FROM re_review_assignment WHERE re_review_batch = ",
      re_review_batch_unassign,
      ";"))

    dbDisconnect(sysndd_db)

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Read access forbidden."))
  }
}


#* Get Re-Review Assignment Table
#*
#* This endpoint returns a summary table of currently assigned re-review batches
#* for administrators and curators.
#*
#* # `Details`
#* The function fetches and returns a summary table of re-review batch
#* assignments. Access is restricted to administrators and curators.
#*
#* # `Return`
#* Returns a summary table of re-review batch assignments if successful, or an
#* error message otherwise.
#*
#* @tag re_review
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns the summary table of re-review batch assignments.
#* @response 401 Unauthorized. The user is not authenticated.
#* @response 403 Forbidden. The user does not have the necessary permissions.
#*
#* @get /api/re_review/assignment_table
function(req, res) {

  user <- req$user_id

  # first check rights
  if (length(user) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (req$user_role %in% c("Administrator", "Curator")) {

    re_review_entity_connect_table <- pool %>%
      tbl("re_review_entity_connect") %>%
      select(re_review_batch,
        re_review_review_saved,
        re_review_status_saved,
        re_review_submitted,
        re_review_approved) %>%
      group_by(re_review_batch) %>%
      collect() %>%
      mutate(entity_count = 1) %>%
      summarize_at(vars(re_review_review_saved:entity_count), sum)

    re_review_assignment_table <- pool %>%
      tbl("re_review_assignment")

    user_table <- pool %>%
      tbl("user") %>%
      select(user_id, user_name)

    re_review_assign_table_user <- re_review_assignment_table %>%
      left_join(user_table, by = c("user_id")) %>%
      collect() %>%
      left_join(re_review_entity_connect_table, by = c("re_review_batch")) %>%
      select(assignment_id,
        user_id,
        user_name,
        re_review_batch,
        re_review_review_saved,
        re_review_status_saved,
        re_review_submitted,
        re_review_approved,
        entity_count) %>%
      arrange(user_id)

    # return tibble
    re_review_assign_table_user
  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Read access forbidden."))
  }
}

## Re-review endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Publication endpoints

#* Fetch Publication by PMID
#*
#* This endpoint fetches a publication from the database based on the provided
#* PubMed ID (PMID).
#*
#* # `Details`
#* Retrieves a publication's metadata, such as title, abstract, authors, and
#* publication date, based on its PMID.
#*
#* # `Return`
#* Returns the publication metadata as JSON.
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param pmid The PubMed ID of the publication.
#*
#* @response 200 OK. Returns the publication metadata.
#*
#* @get /api/publication/<pmid>
function(pmid) {

  pmid <- URLdecode(pmid) %>%
    str_replace_all("[^0-9]+", "")
  pmid <- paste0("PMID:", pmid)

  # get data from database and filter
  publication_collected <- pool %>%
    tbl("publication") %>%
    filter(publication_id == pmid) %>%
    select(publication_id,
      other_publication_id,
      Title,
      Abstract,
      Lastname,
      Firstname,
      Publication_date,
      Journal,
      Keywords) %>%
    arrange(publication_id) %>%
    collect()
}


#* Validate PMID Existence in PubMed
#*
#* This endpoint validates whether a given PubMed ID (PMID) exists in PubMed.
#*
#* # `Details`
#* Validates the existence of a PMID in the PubMed database.
#*
#* # `Return`
#* Returns a JSON object indicating the validation result.
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param pmid The PubMed ID to validate.
#*
#* @response 200 OK. Returns the validation result.
#*
#* @get /api/publication/validate/<pmid>
function(req, res, pmid) {

  pmid <- URLdecode(pmid) %>%
    str_replace_all("[^0-9]+", "")

  check_pmid(pmid)
}


#* Search Publications on PubTator
#*
#* This endpoint queries the PubTator API to retrieve publications based on a given search query.
#* It allows pagination through the results.
#*
#* # `Details`
#* Retrieves a list of publications' metadata, such as PMIDs, titles, journals, and dates,
#* based on the search query. Supports pagination through the results.
#*
#* # `Return`
#* Returns a list of publications' metadata as JSON.
#*
#* @tag publication
#* @serializer json list(na="string")
#*
#* @param current_page Numeric: The starting page number for the API response (for pagination).
#*
#* @response 200 OK. Returns the list of publications' metadata.
#*
#* @get /api/publication/pubtator/search
function(req, res, current_page = 1) {

  # TODO: Put this in a config or allow user input
  query <- '("intellectual disability" OR "mental retardation" OR "autism" OR "epilepsy" OR "neurodevelopmental disorder" OR "neurodevelopmental disease" OR "epileptic encephalopathy") AND (gene OR syndrome) AND (variant OR mutation)'

  max_pages <- 1

  # Validate and process input parameters
  current_page <- as.numeric(current_page)

  # Call the function to fetch data from PubTator
  pmids_data <- pubtator_v3_pmids_from_request(query, current_page, max_pages)

  # Calculate the total pages based on your query and items per page
  per_page <- 10
  total_pages <- pubtator_v3_total_pages_from_query(query)

  # Create the response data structure
  # TODO: fix arrays retured as strings
  response_data <- list(
    meta = list(
      "perPage" = per_page,
      "currentPage" = current_page,
      "totalPages" = total_pages
    ),
    data = pmids_data
  )

  # Return the response as JSON
  res$status <- 200
  return(response_data)
}


## Publication endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Gene endpoints

#* Fetch Gene Data with Filters and Field Selection
#*
#* This endpoint fetches gene data from the database, allowing for filtering,
#* field selection, and pagination.
#*
#* # `Details`
#* Retrieves gene data with optional filters, sorting, and pagination. Users
#* can also specify the fields they want to be returned.
#*
#* # `Return`
#* Returns a paginated list of genes based on the provided filters.
#*
#* @tag gene
#* @serializer json list(na="string")
#*
#* @param sort The column to sort the output by.
#* @param filter Filters to apply.
#* @param fields Fields to be returned in the output.
#* @param page_after Cursor for pagination.
#* @param page_size Size of the page for pagination.
#* @param fspec Field specifications for meta data response.
#*
#* @response 200 OK. Returns the filtered and paginated list of genes.
#*
#* @get /api/gene
function(req,
  res,
  sort = "symbol",
  filter = "",
  fields = "",
  `page_after` = "0",
  `page_size` = "10",
  fspec = "symbol,category,hpo_mode_of_inheritance_term_name,ndd_phenotype_word,entities_count,details",
  format = "json") {
  # set serializers
  res$serializer <- serializers[[format]]

  # TODO: Put all of this into and endpoint function
  # start time calculation
  start_time <- Sys.time()
  # generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "symbol")

  # generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # get data from database and filter
  sysndd_db_genes_table <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    collect() %>%
    group_by(symbol) %>%
    mutate(entities_count = n()) %>%
    ungroup()

  # apply filters according to input and arrange
  sysndd_db_genes_table_filtered <- sysndd_db_genes_table %>%
    filter(!!!rlang::parse_exprs(filter_exprs)) %>%
    arrange(!!!rlang::parse_exprs(sort_exprs))

  # use the helper generate_tibble_fspec to
  # generate fields specs from a tibble
  sysndd_db_genes_table_fspec <- generate_tibble_fspec_mem(
    sysndd_db_genes_table,
    fspec)

  sysndd_db_genes_table_filtered_fspec <- generate_tibble_fspec_mem(
    sysndd_db_genes_table_filtered,
    fspec)

  sysndd_db_genes_table_fspec$fspec$count_filtered <- sysndd_db_genes_table_filtered_fspec$fspec$count

  # nest
  sysndd_db_genes_nested <- nest_gene_tibble_mem(sysndd_db_genes_table_filtered)

  # select fields from table based on
  # input using the helper function "select_tibble_fields"
  sysndd_db_genes_nested <- select_tibble_fields(
    sysndd_db_genes_nested,
    fields,
    "symbol")

  # use the helper generate_cursor_pagination
  # info to generate cursor pagination information from a tibble
  genes_nested_pag_info <- generate_cursor_pag_inf(
    sysndd_db_genes_nested,
    `page_size`,
    `page_after`,
    "symbol")

  # compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(paste0(round(end_time - start_time, 2),
  " secs"))

  # add columns to the meta information from
  # generate_cursor_pag_inf function return
  meta <- genes_nested_pag_info$meta %>%
    add_column(tibble::as_tibble(list("sort" = sort,
      "filter" = filter,
      "fields" = fields,
      "fspec" = sysndd_db_genes_table_fspec,
      "executionTime" = execution_time)))

  # add host, port and other information to links from the link
  # information from generate_cursor_pag_inf function return
  links <- genes_nested_pag_info$links %>%
      pivot_longer(everything(), names_to = "type", values_to = "link") %>%
    mutate(link = case_when(
      link != "null" ~ paste0(
        dw$api_base_url,
        "/api/gene?sort=",
        sort,
        ifelse(filter != "", paste0("&filter=", filter), ""),
        ifelse(fields != "", paste0("&fields=", fields), ""),
        link),
      link == "null" ~ "null"
    )) %>%
      pivot_wider(id_cols = everything(), names_from = "type", values_from = "link")

  # generate object to return
  gene_list <- list(links = links,
    meta = meta,
    data = genes_nested_pag_info$data)

  # if xlsx requested compute this and return
  if (format == "xlsx") {
    #TODO: move this to a helper function and collapse again as strings
    # unnest data
    gene_list$data <- gene_list$data %>%
      unnest(c(entities), names_sep = "_")

    # generate creation date statistic for output
    creation_date <- strftime(as.POSIXlt(Sys.time(),
      "UTC",
      "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S")

    # generate base filename from api name
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
        str_replace_all("_api_", "")

    filename <- file.path(paste0(base_filename,
      "_",
      creation_date,
      ".xlsx"))

    # generate xlsx bin using helper function
    bin <- generate_xlsx_bin(gene_list, base_filename)

    # Return the binary contents
    as_attachment(bin, filename)
  } else {
    gene_list
  }
}


#* Fetch Single Gene Information
#*
#* This endpoint fetches detailed information for a single gene based on either
#* its HGNC ID or symbol.
#*
#* # `Details`
#* Retrieves detailed gene information including associated IDs and names.
#*
#* # `Return`
#* Returns detailed information of the specified gene.
#*
#* @tag gene
#* @serializer json list(na="null")
#*
#* @param gene_input The HGNC ID or symbol of the gene.
#* @param input_type The type of input ('hgnc' or 'symbol').
#*
#* @response 200 OK. Returns detailed information of the gene.
#*
#* @get /api/gene/<gene_input>
function(gene_input, input_type = "hgnc") {

  # conditionally url decode and reformat input
  if (input_type == "hgnc") {
    gene_input <- URLdecode(gene_input) %>%
      str_replace_all("HGNC:", "")
    gene_input <- paste0("HGNC:", gene_input)
  } else if (input_type == "symbol") {
    gene_input <- URLdecode(gene_input) %>%
      str_to_lower()
  }

  # get data from database and filter
  non_alt_loci_set_collected <- pool %>%
    tbl("non_alt_loci_set") %>%
    {if (input_type == "hgnc")
      filter(., hgnc_id == gene_input)
     else .
     } %>%
    {if (input_type == "symbol")
      filter(., str_to_lower(symbol) == gene_input)
     else .
     } %>%
    select(hgnc_id,
      symbol,
      name,
      entrez_id,
      ensembl_gene_id,
      ucsc_id,
      ccds_id,
      uniprot_ids,
      omim_id,
      mane_select,
      mgd_id,
      rgd_id,
      STRING_id) %>%
    arrange(hgnc_id) %>%
    collect() %>%
    mutate(across(everything(), ~str_split(., pattern = "\\|")))
}

## Gene endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Ontology endpoints

#* Fetch Ontology Entry by ID
#*
#* This endpoint fetches an ontology entry based on its disease_ontology_id_version.
#*
#* # `Details`
#* Retrieves detailed information about an ontology term, including associated
#* HGNC IDs and inheritance terms.
#*
#* # `Return`
#* Returns detailed information of the specified ontology term.
#*
#* @tag ontology
#* @serializer json list(na="null")
#*
#* @param ontology_input The disease_ontology_id_version of the ontology term.
#* @param input_type The type of input ('ontology_id').
#*
#* @response 200 OK. Returns detailed information of the ontology term.
#*
#* @get /api/ontology/<ontology_input>
function(ontology_input, input_type = "ontology_id") {
  # decode URL
  ontology_input <- URLdecode(ontology_input)

  # get data from database and filter
  mode_of_inheritance_list_coll <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    filter(is_active == 1) %>%
    select(hpo_mode_of_inheritance_term,
        hpo_mode_of_inheritance_term_name,
        inheritance_filter) %>%
    collect()

  # get data from database and filter
  disease_ontology_set <- pool %>%
    tbl("disease_ontology_set") %>%
    collect()

  # TODO: review this whole pipe and the EP (seems duplicated with search)
  disease_ontology_set_collected <- disease_ontology_set %>%
    mutate(disease_ontology_id_search = disease_ontology_id) %>%
    mutate(disease_ontology_name_search = disease_ontology_name) %>%
    pivot_longer(
      cols = disease_ontology_id_search:disease_ontology_name_search,
      names_to = "type",
      values_to = "search"
    ) %>%
    filter(search == ontology_input) %>%
    select(disease_ontology_id_version,
      disease_ontology_id,
      disease_ontology_name,
      disease_ontology_source,
      disease_ontology_is_specific,
      hgnc_id,
      hpo_mode_of_inheritance_term,
      DOID,
      MONDO,
      Orphanet,
      EFO) %>%
    arrange(disease_ontology_id_version) %>%
    left_join(mode_of_inheritance_list_coll,
        by = c("hpo_mode_of_inheritance_term")) %>%
    group_by(disease_ontology_id) %>%
    summarize_all(~paste(unique(.), collapse = ";")) %>%
    ungroup() %>%
    mutate(across(everything(), ~replace(., . == "NA", NA))) %>%
    mutate(across(everything(), ~str_split(., pattern = "\\;")))

    disease_ontology_set_collected
}

## Ontology endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Phenotype endpoints

#* Get a List of Entities Associated with a List of Phenotypes
#*
#* # `Details`
#* This endpoint retrieves a list of entities associated with specified phenotypes based on the data in the database.
#*
#* # `Return`
#* Returns a data frame containing the list of entities associated with the list of phenotypes.
#*
#* @tag phenotype
#* @serializer json list(na="string")
#*
#* @param sort:str Output column to arrange output on.
#* @param filter:str Comma separated list of filters to apply.
#* @param fields:str Comma separated list of output columns.
#* @param page_after:str Cursor after which to show entries in cursor pagination.
#* @param page_size:str Page size in cursor pagination.
#* @param fspec:str Fields for which to generate the field specification in the meta data response.
#* @param format:str The output format, either "json" or "xlsx". Defaults to "json".
#*
#* @get /api/phenotype/entities/browse
function(req,
  res,
  sort = "entity_id",
  filter = "",
  fields = "",
  `page_after` = "0",
  `page_size` = "10",
  fspec = "entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details",
  format = "json") {
  # set serializers
  res$serializer <- serializers[[format]]

  # call the endpoint function generate_phenotype_entities
  phenotype_entities_list <- generate_phenotype_entities_list(sort,
    filter,
    fields,
    `page_after`,
    `page_size`,
    fspec)

  # if xlsx requested compute this and return
  if (format == "xlsx") {
    # generate creation date statistic for output
    creation_date <- strftime(as.POSIXlt(Sys.time(),
      "UTC",
      "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S")

    # generate base filename from api name
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
        str_replace_all("_api_", "")

    filename <- file.path(paste0(base_filename,
      "_",
      creation_date,
      ".xlsx"))

    # generate xlsx bin using helper function
    bin <- generate_xlsx_bin(phenotype_entities_list, base_filename)

    # Return the binary contents
    as_attachment(bin, filename)
  } else {
    phenotype_entities_list
  }
}


#* Get Correlation between Phenotypes
#*
#* This endpoint returns the correlation matrix between phenotypes based on
#* the data in the database.
#*
#* # `Details`
#* Retrieves the correlation matrix between specified phenotypes.
#*
#* # `Return`
#* A data frame containing the correlation matrix between phenotypes,
#* with the columns "x", "x_id", "y", "y_id", and "value". The "x" and "y"
#* columns represent the names of the phenotypes, the "x_id" and "y_id" columns
#* represent the corresponding HPO IDs, and the "value" column represents the
#* correlation coefficient between the two phenotypes.
#*
#* @tag phenotype
#* @serializer json list(na="string")
#*
#* @param filter:str A string representing a filter query to use when selecting
#* data from the database.
#*
#* @get /api/phenotype/correlation
function(res,
  filter = "contains(ndd_phenotype_word,Yes),any(category,Definitive)") {

  # TODO: add option to called function to immediately return long format
  # call the endpoint function generate_phenotype_entities
  phenotype_entities_data <- generate_phenotype_entities_list(
    filter = filter)$data %>%
    separate_rows(modifier_phenotype_id, sep = ",") %>%
    unique()

  # get data from database, filter and restructure
  phenotype_list_tbl <- pool %>%
    tbl("phenotype_list") %>%
    collect()

  # compose table
  sysndd_db_phenotypes <- phenotype_entities_data %>%
    filter(str_detect(modifier_phenotype_id, "1-")) %>%
    # remove the modifier
    mutate(phenotype_id = str_remove(modifier_phenotype_id, "[1-4]-")) %>%
    # remove the general HP:0001249 term present in all definitive entities
    filter(phenotype_id != "HP:0001249") %>%
    left_join(phenotype_list_tbl, by = c("phenotype_id")) %>%
    select(entity_id, phenotype_id, HPO_term)

  # compute correlation matrix
  sysndd_db_phenotypes_matrix <- sysndd_db_phenotypes %>%
    select(-phenotype_id) %>%
    mutate(has_HPO_term = HPO_term) %>%
    mutate(has_HPO_term = case_when(
        !is.na(has_HPO_term) ~ 1
      )) %>%
    unique() %>%
    pivot_wider(names_from = HPO_term, values_from = has_HPO_term) %>%
    replace(is.na(.), 0) %>%
    select(-entity_id)

  # compute correlation matrix
  sysndd_db_phenotypes_corr <- round(cor(sysndd_db_phenotypes_matrix), 2)
  phenotypes_corr_melted <- melt(sysndd_db_phenotypes_corr) %>%
      select(x = Var1, y = Var2, value)

  # join with HPO ids
  phenotype_list_join <- phenotype_list_tbl %>%
    select(phenotype_id, HPO_term)

  phenotypes_corr_melted_ids <- phenotypes_corr_melted %>%
    left_join(phenotype_list_join, by = c("x" = "HPO_term")) %>%
    select(x, y, value, x_id = phenotype_id) %>%
    left_join(phenotype_list_join, by = c("y" = "HPO_term")) %>%
    select(x, x_id, y, y_id = phenotype_id, value)

  # return the object
  phenotypes_corr_melted_ids
}


#* Get Counts of Phenotypes in Annotated Entities
#*
#* This endpoint returns the counts of phenotypes in annotated entities based on
#* the data in the database.
#*
#* # `Details`
#* Retrieves the counts of phenotypes in annotated entities.
#*
#* # `Return`
#* A data frame containing the counts of phenotypes in annotated
#* entities, with the columns "HPO_term", "phenotype_id", and "count". The
#* "HPO_term" column represents the name of the phenotype, the "phenotype_id"
#* column represents the corresponding HPO ID, and the "count" column represents
#* the number of times the phenotype appears in annotated entities.
#*
#* @tag phenotype
#* @serializer json list(na="string")
#*
#* @param filter:str A string representing a filter query to use when selecting
#* data from the database.
#*
#* @get /api/phenotype/count
function(res,
  filter = "contains(ndd_phenotype_word,Yes),any(category,Definitive)") {

  # TODO: add option to called function to immediately return long format
  # call the endpoint function generate_phenotype_entities
  phenotype_entities_data <- generate_phenotype_entities_list(
    filter = filter)$data %>%
    separate_rows(modifier_phenotype_id, sep = ",") %>%
    unique()

  # get data from database, filter and restructure
  phenotype_list_tbl <- pool %>%
    tbl("phenotype_list") %>%
    collect()

  # TODO: change endpoint to also present modifier information
  # compose table
  sysndd_db_phenotypes <- phenotype_entities_data %>%
    # remove the modifier
    # added 5: "absent"
    mutate(phenotype_id = str_remove(modifier_phenotype_id, "[1-5]-")) %>%
    # remove the general HP:0001249 term present in all definitive entities
    filter(phenotype_id != "HP:0001249") %>%
    left_join(phenotype_list_tbl, by = c("phenotype_id")) %>%
    select(entity_id, phenotype_id, HPO_term)

  # compute counts
  sysndd_db_phenotypes_count <- sysndd_db_phenotypes %>%
      group_by(HPO_term, phenotype_id) %>%
      tally() %>%
      arrange(desc(n)) %>%
      ungroup() %>%
      select(HPO_term, phenotype_id, count = n)

  # generate object to return
  sysndd_db_phenotypes_count
}
## Phenotype endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Status endpoints

#* Get the Status List
#*
#* This endpoint retrieves the status list for entities. It allows optional filtering 
#* based on the approval status. The status details include gene and disease information, 
#* associated reviews, user details, and other associated metadata.
#*
#* # `Details`
#* The function first decodes the provided review ID and removes any spaces. 
#* It then fetches data from various database tables, such as gene information, disease 
#* ontology, mode of inheritance, and status approval view. It joins and filters these 
#* datasets to create a comprehensive status list. The function also computes a review 
#* table to determine any changes in the review status.
#*
#* # `Return`
#* The function returns a data frame containing the status list with associated 
#* metadata. Each row represents the status for a specific entity.
#*
#* @tag status
#* @serializer json list(na="null")
#*
#* @param review_id_requested: The ID of the review for which the status list is requested.
#* @param filter_status_approved: Boolean flag indicating if the results should be filtered 
#*                                based on approval status.
#*
#* @response 200: Returns a list containing the status details for the specified review ID.
#*
#* @get /api/status
function(req, res, filter_status_approved = FALSE) {

  # TODO: maybe this endpoint should be authenticated
  # make sure filter_status_approved input is logical
  filter_status_approved <- as.logical(filter_status_approved)

  # get data from database and filter
  entity_status_categories_coll <- pool %>%
    tbl("ndd_entity_status_categories_list")
  # user information from user table
  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, user_name, user_role)
  # gene information from non_alt_loci_set table
  non_alt_loci_set <- pool %>%
    tbl("non_alt_loci_set") %>%
    select(hgnc_id, symbol)
  # disease information from disease_ontology_set table
  disease_ontology_set <- pool %>%
    tbl("disease_ontology_set") %>%
    select(disease_ontology_id,
      disease_ontology_id_version,
      disease_ontology_name)
  # moi information from mode_of_inheritance_list table
  mode_of_inheritance_list <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    select(-is_active, -sort)
  # approved status from ndd_entity_status_approved_view view
  ndd_entity_status_approved_view <- pool %>%
    tbl("ndd_entity_status_approved_view") %>%
    select(entity_id, status_approved, category_id)
  # categories status from ndd_entity_status_categories_list table
  ndd_entity_status_categories_list <- pool %>%
    tbl("ndd_entity_status_categories_list")
  # boolean values from boolean_list table
  boolean_list <- pool %>%
    tbl("boolean_list")

  # generate entity table with human readable information
  # TODO: replace with entity_view (then filtered in other EPs)
  ndd_entity_tbl <- pool %>%
    tbl("ndd_entity") %>%
    left_join(non_alt_loci_set,
      by = c("hgnc_id")) %>%
    left_join(disease_ontology_set,
      by = c("disease_ontology_id_version")) %>%
    left_join(mode_of_inheritance_list,
      by = c("hpo_mode_of_inheritance_term")) %>%
    left_join(ndd_entity_status_approved_view,
      by = c("entity_id")) %>%
    left_join(ndd_entity_status_categories_list,
      by = c("category_id")) %>%
    left_join(boolean_list,
      by = c("ndd_phenotype" = "logical")) %>%
    select(entity_id,
      hgnc_id,
      symbol,
      disease_ontology_id_version,
      disease_ontology_name,
      hpo_mode_of_inheritance_term,
      hpo_mode_of_inheritance_term_name)

  # join the table and apply filters
  status_table_collected <- pool %>%
    tbl("ndd_entity_status") %>%
    inner_join(entity_status_categories_coll, by = c("category_id")) %>%
    left_join(user_table, by = c("status_user_id" = "user_id")) %>%
    left_join(user_table, by = c("approving_user_id" = "user_id")) %>%
    left_join(ndd_entity_tbl, by = c("entity_id")) %>%
    filter(status_approved == filter_status_approved) %>%
    collect() %>%
    select(status_id,
      entity_id,
      hgnc_id,
      symbol,
      disease_ontology_id_version,
      disease_ontology_name,
      hpo_mode_of_inheritance_term,
      hpo_mode_of_inheritance_term_name,
      category,
      category_id,
      is_active,
      status_date,
      status_user_name = user_name.x,
      status_user_role = user_role.x,
      status_approved,
      approving_user_name = user_name.y,
      approving_user_role = user_role.y,
      approving_user_id,
      comment,
      problematic) %>%
    arrange(entity_id, status_date) %>%
    # check if duplicate values exist
    group_by(entity_id) %>%
    mutate(duplicate = n()) %>%
    mutate(duplicate = case_when(
      duplicate == 1 ~ "no",
      TRUE ~ "yes"
    )) %>%
    ungroup()

  # compute review table
  review_table <- pool %>%
      tbl("ndd_entity_review") %>%
      collect() %>%
      filter(entity_id %in% status_table_collected$entity_id) %>%
      select(entity_id, review_id, is_primary, review_date) %>%
      arrange(entity_id) %>%
      group_by(entity_id) %>%
      mutate(active_review = case_when(
              is_primary == max(is_primary) ~ review_id
          )
      ) %>%
      mutate(newest_review = case_when(
              review_date == max(review_date) ~ review_id
          )
      ) %>%
      select(entity_id,
        active_review,
        newest_review) %>%
      mutate(active_review = max(active_review, na.rm = TRUE),
          newest_review = max(newest_review, na.rm = TRUE),
      ) %>%
      ungroup() %>%
      unique() %>%
      mutate(review_change = as.numeric(!(active_review == newest_review)))

  status_table_collected <- status_table_collected %>%
    left_join(review_table, by = c("entity_id"))

  status_table_collected
}


#* Get Single Status by Status ID
#*
#* This endpoint retrieves detailed status information for a specific status ID. 
#* The information includes associated user details, category of the status, approval 
#* details, and other relevant metadata.
#*
#* # `Details`
#* The function first decodes the provided status ID and removes any spaces. It then fetches 
#* data from the `ndd_entity_status` database table and joins it with user information and 
#* status categories to create a detailed status report.
#*
#* # `Return`
#* The function returns a data frame containing the detailed status information for the 
#* specified status ID.
#*
#* @tag status
#* @serializer json list(na="null")
#*
#* @param status_id_requested: The ID of the status for which detailed information is requested.
#*
#* @response 200: Returns a list containing the status details for the specified status ID.
#*
#* @get /api/status/<status_id_requested>
function(status_id_requested) {
  # remove spaces from list
  status_id_requested <- URLdecode(status_id_requested) %>%
    str_split(pattern = ",", simplify = TRUE) %>%
    str_replace_all(" ", "") %>%
    unique()

  # get data from database and filter
  sysndd_db_status_table <- pool %>%
    tbl("ndd_entity_status")

  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, user_name, user_role)

  entity_status_categories_coll <- pool %>%
    tbl("ndd_entity_status_categories_list")

  status_table_collected <- sysndd_db_status_table %>%
    filter(status_id == status_id_requested) %>%
    inner_join(entity_status_categories_coll, by = c("category_id")) %>%
    left_join(user_table, by = c("status_user_id" = "user_id")) %>%
    left_join(user_table, by = c("approving_user_id" = "user_id")) %>%
    collect() %>%
    select(status_id,
      entity_id,
      category,
      category_id,
      is_active,
      status_date,
      status_user_name = user_name.x,
      status_user_role = user_role.x,
      status_approved,
      approving_user_name = user_name.y,
      approving_user_role = user_role.y,
      comment,
      problematic) %>%
    arrange(status_date)

  status_table_collected
}


#* Get List of All Status
#*
#* This endpoint retrieves a list of all available status categories from the `ndd_entity_status_categories_list` 
#* database table. The list is sorted based on the `category_id`.
#*
#* # `Details`
#* The function fetches the list of status categories from the database and arranges them in ascending order 
#* based on the `category_id`.
#*
#* # `Return`
#* The function returns a data frame containing the list of all available status categories.
#*
#* @tag status
#* @serializer json list(na="string")
#*
#* @response 200: Returns a list containing all available status categories.
#*
#* @get /api/status_list
function() {
  status_list_collected <- pool %>%
    tbl("ndd_entity_status_categories_list") %>%
    arrange(category_id) %>%
    collect()
}


#* Create or Update Entity Status
#*
#* This endpoint allows for the creation of a new status for a given `entity_id` 
#* or the update of an existing status based on the `status_id`. Users must provide 
#* the `status_id` when making a PUT request and the `entity_id` when making a POST request.
#* Only users with roles "Administrator", "Curator", or "Reviewer" have the rights to access this endpoint.
#*
#* # `Details`
#* The function first checks the user's role for necessary permissions. If permitted, 
#* it then proceeds to either create a new status or update an existing one based on 
#* the request method.
#*
#* # `Parameters`
#* `re_review`: A logical parameter indicating whether a re-review is required. Defaults to FALSE.
#* `status_json`: A JSON object containing the status data. Example: 
#* '{"status_id":3,"entity_id":3,"category_id":1,"comment":"fsa","problematic": true}'
#*
#* # `Return`
#* The function returns a response containing the status of the operation and 
#* any associated messages or errors.
#*
#* @tag status
#* @serializer json list(na="string")
#*
#* @response 200: Returns a success message.
#* @response 403: User does not have permission to write.
#*
#* @post /api/status/create
#* @put /api/status/update
function(req, res, re_review = FALSE) {

  # first check rights
  if (req$user_role %in% c("Administrator", "Curator", "Reviewer")) {
    # make sure re_review input is logical
    re_review <- as.logical(re_review)

    status_data <- req$argsBody$status_json

    status_data$status_user_id <- req$user_id

    response <- put_post_db_status(
      req$REQUEST_METHOD,
      status_data,
      re_review)

    res$status <- response$status
    return(response)

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Write access forbidden."))
  }
}

#* Approve Entity Status
#*
#* This endpoint allows users with roles "Administrator" or "Curator" to approve a given status 
#* associated with a specific `status_id`. This is done by sending a PUT request with the desired 
#* `status_id` in the URL.
#*
#* # `Details`
#* The function first checks if the user is authenticated. If the user is not authenticated, 
#* a 401 Unauthorized response is returned. If authenticated, the user's role is checked to 
#* determine if they have the necessary permissions. If permitted, the status is approved or 
#* disapproved based on the `status_ok` parameter.
#*
#* # `Parameters`
#* `status_ok`: A logical parameter indicating whether the status is approved. Defaults to FALSE.
#*
#* # `Return`
#* The function returns a response containing the status of the operation and 
#* any associated messages or errors.
#*
#* @tag status
#* @serializer json list(na="string")
#* 
#* @response 200: Returns a success message.
#* @response 401: User is not authenticated.
#* @response 403: User does not have permission to write.
#* 
#* @put /api/status/approve/<status_id_requested>
function(req, res, status_id_requested, status_ok = FALSE) {
  # make sure status_ok input is logical
  status_ok <- as.logical(status_ok)

  # first check rights
  if (length(req$user_id) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (req$user_role %in% c("Administrator", "Curator")) {

    submit_user_id <- req$user_id

    # use the "put_db_status_approve" function to add the
    # approval to the database table
    response_status_approve <- put_db_status_approve(
        status_id_requested,
        submit_user_id,
        status_ok)

    # emit response
    response_status_approve

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Write access forbidden."))
  }
}

## status endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Panels endpoints

#* Get List of All Panel Filtering Options
#*
#* This endpoint retrieves a list of all available filtering options for panels.
#*
#* # `Details`
#* Connects to the database and retrieves categories, inheritance, and columns.
#*
#* # `Return`
#* Returns lists of categories, inheritance terms, and columns.
#*
#* @tag panels
#* @serializer json list(na="string")
#* @get /api/panels/options
function() {
  # connect to database and get category list
  categories_list <- pool %>%
    tbl("ndd_entity_status_categories_list") %>%
    select(category) %>%
    collect() %>%
    filter(category != "not applicable") %>%
    add_row(category = "All") %>%
    arrange(category)

  inheritance_list <- tibble::as_tibble(inheritance_input_allowed) %>%
    select(inheritance = value) %>%
    arrange(inheritance)

  columns_list <- tibble::as_tibble(output_columns_allowed) %>%
    select(column = value)

  options <- tibble(
    lists = c("categories_list", "inheritance_list", "columns_list"),
    options = list(
      tibble(value = categories_list$category),
      tibble(value = inheritance_list$inheritance),
      tibble(value = columns_list$column)
      )
  )

  options
}


#* Browse Panel Data
#*
#* This endpoint retrieves panel data based on filters and sorting.
#*
#* # `Details`
#* Retrieves panel data based on category, inheritance, sorting, and filters.
#*
#* # `Return`
#* Returns the filtered and sorted panel data.
#*
#* @tag panels
#* @serializer json list(na="string")
#* 
#* @param sort Output column for sorting.
#* @param filter Filters to apply.
#* @param fields Output columns to include.
#* 
#* @get /api/panels/browse
function(req,
  res,
  sort = "symbol",
  filter = "equals(category,'Definitive'),any(inheritance_filter,'Autosomal dominant','Autosomal recessive','X-linked','Other')",
  fields = "category,inheritance,symbol,hgnc_id,entrez_id,ensembl_gene_id,ucsc_id,bed_hg19,bed_hg38",
  `page_after` = 0,
  `page_size` = "all",
  max_category = TRUE,
  format = "json") {
  # set serializers
  res$serializer <- serializers[[format]]

  # make sure max_category input is logical
  max_category <- as.logical(max_category)

  # call the endpoint function generate_panels_list
  panels_list <- generate_panels_list(sort,
    filter,
    fields,
    `page_after`,
    `page_size`,
    max_category)

  # if xlsx requested compute this and return
  if (format == "xlsx") {
    # generate creation date statistic for output
    creation_date <- strftime(as.POSIXlt(Sys.time(),
      "UTC",
      "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S")

    # generate base filename from api name
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
        str_replace_all("_api_", "")

    filename <- file.path(paste0(base_filename,
      "_",
      creation_date,
      ".xlsx"))

    # generate xlsx bin using helper function
    bin <- generate_xlsx_bin(panels_list, base_filename)

    # Return the binary contents
    as_attachment(bin, filename)
  } else {
    panels_list
  }
}
## Panels endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Statistics endpoints

#* Get Category Count Statistics
#*
#* This endpoint retrieves statistics for genes with a NDD phenotype.
#*
#* # `Details`
#* Retrieves statistics on entities by category and inheritance type.
#*
#* # `Return`
#* Returns the category count statistics.
#*
#* @tag statistics
#* @serializer json list(na="string")
#* 
#* @get /api/statistics/category_count
function(sort = "category_id,-n",
  type = "gene") {
 disease_genes_statistics <- generate_stat_tibble_mem(sort, type)

 disease_genes_statistics
}


#* Get News Entries
#*
#* This endpoint retrieves the last n entries in the definitive category.
#*
#* # `Details`
#* Retrieves latest entries in the definitive category as news.
#*
#* # `Return`
#* Returns the latest news entries.
#*
#* @tag statistics
#* @serializer json list(na="string")
#* 
#* @param n Number of latest entries to retrieve.
#* 
#* @get /api/statistics/news
function(n = 5) {
 sysndd_db_disease_genes_news <- generate_gene_news_tibble_mem(n)

 sysndd_db_disease_genes_news
}


#* Get Entities Over Time
#*
#* This endpoint retrieves database entry development over time.
#*
#* # `Details`
#* Retrieves the cumulative count of entities over time.
#*
#* # `Return`
#* Returns the cumulative count of entities over time.
#*
#* @tag statistics
#* @serializer json list(na="string")
#*
#* @param aggregate Aggregation level ('entity_id' or 'symbol').
#* @param group Grouping level ('category', 'inheritance_filter', or 
#*             'inheritance_multiple').
#* @param summarize Time summarization level ('month').
#* @param filter Filters to apply.
#*
#* @get /api/statistics/entities_over_time
function(res,
  aggregate = "entity_id",
  group = "category",
  summarize = "month",
  filter = "contains(ndd_phenotype_word,Yes),any(inheritance_filter,Autosomal dominant,Autosomal recessive,X-linked)") {

  start_time <- Sys.time()

  # check input
  if (!(aggregate %in% c("entity_id", "symbol")) ||
      !(group %in% c("category",
        "inheritance_filter",
        "inheritance_multiple"))) {
    res$status <- 400
    res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
    status = 400,
    message = paste0("Required 'aggregate' or 'group' ",
      "parameter not in categories list.")
    ))
    return(res)
  }

  if (aggregate == "entity_id" &&
      group == "inheritance_multiple") {
    res$status <- 400
    res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
    status = 400,
    message = paste0("Multiple inheritance only ",
      "sensible when grouping by gene symbol.")
    ))
    return(res)
  }

  # generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # get data from database and filter
  entity_view_coll <- pool %>%
    tbl("ndd_entity_view") %>%
    collect()

  # apply filters according to input
  entity_view_filtered <- entity_view_coll %>%
    filter(!!!rlang::parse_exprs(filter_exprs)) %>%
    arrange(entry_date, entity_id) %>% ## <-- arrange by entry_date
      { if (aggregate == "symbol")
        group_by(., symbol) %>%
        ## <-- group by symbol
        mutate(., entities_count = n()) %>%
        ## <-- generate entities count
        mutate(., inheritance_filter_count = n_distinct(inheritance_filter)) %>%
        ## <-- generate inheritance_filter count
        mutate(., inheritance_multiple = str_c(
          inheritance_filter %>% unique(),
          collapse = " | ")
        ) %>%
        ## <-- concatenate inheritance_filter
        ungroup(.)
      else .
      } %>%
      { if (group == "inheritance_multiple")
        ## <-- conditional pipe to remove entries with one inh. pat.
        filter(., inheritance_filter_count > 1)
      else .
      } %>%
    ## <-- arrange according aggregate parameter
    arrange(!!rlang::sym(aggregate)) %>%
    select(!!rlang::sym(aggregate),
      !!rlang::sym(group),
      entry_date) %>%
      { if (aggregate == "symbol")
        ## <-- conditional pipe to remove duplicate
        group_by(., symbol) %>%
        ## genes with multiple entries and same inheritance
        mutate(., entry_date = min(entry_date)) %>%
        ungroup(.) %>%
        unique(.)
      else .
      }

  # calculate summary statistics by date
  entity_view_cumsum <- entity_view_filtered %>%
    mutate(count = 1) %>%
    arrange(entry_date) %>%
    group_by(!!rlang::sym(group)) %>%
    summarize_by_time(
      .date_var = entry_date,
      .by       = rlang::sym(summarize), # <-- Setup for monthly aggregation
      .type = "ceiling", # <-- this is the upper bound for filtering
      # Summarization
      count  = sum(count)
    ) %>%
    mutate(cumulative_count = cumsum(count)) %>%
    ungroup() %>%
    mutate(entry_date = strftime(entry_date, "%Y-%m-%d"))

  # generate object to return
  entity_view_nested <- entity_view_cumsum %>%
    tidyr::nest(.by = !!rlang::sym(group), .key = "values") %>%
    ungroup() %>%
    select("group" = !!rlang::sym(group), values)

  # compute execution time
  end_time <- Sys.time()
  execution_time <- as.character(paste0(round(end_time - start_time, 2),
  " secs"))

  # add columns to the meta information from
  # generate_cursor_pag_inf function return
  meta <- tibble::as_tibble(list("aggregate" = aggregate,
    "group" = group,
    "summarize" = summarize,
    "filter" = filter,
    "max_count" = max(entity_view_cumsum$count),
    "max_cumulative_count" = max(entity_view_cumsum$cumulative_count),
    "executionTime" = execution_time))

  # generate object to return
  list(meta = meta, data = entity_view_nested)
}

## Statistics endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Comparisons endpoints

#* Get Panel Filtering Options for Comparisons
#*
#* This endpoint provides a list of all filtering options for panels
#* in the comparison view.
#*
#* # `Details`
#* Retrieves a list of all filtering options for panels in the comparison view.
#*
#* # `Return`
#* Returns a list of filtering options.
#*
#* @tag comparisons
#* @serializer json list(na="string")
#* 
#* @get /api/comparisons/options
function() {
  # connect to database and get comparisons view
  ndd_database_comparison_view <- pool %>%
    tbl("ndd_database_comparison_view") %>%
    collect()

  list <- ndd_database_comparison_view %>%
    select(list) %>%
    group_by(list) %>%
    # count number of entries for sorting
    mutate(count = n()) %>%
    unique() %>%
    # check if value equals SysNDD
    mutate(self = (list == "SysNDD")) %>%
    # sort so self is top, then the databases with most entries descending
    arrange(desc(self), desc(count)) %>%
    select(list)

  inheritance <- ndd_database_comparison_view %>%
    select(inheritance) %>%
    unique() %>%
    arrange(inheritance)

  category <- ndd_database_comparison_view %>%
    select(category) %>%
    unique() %>%
    arrange(category)

  pathogenicity_mode <- ndd_database_comparison_view %>%
    select(pathogenicity_mode) %>%
    unique() %>%
    arrange(pathogenicity_mode)

  data <- list(
    list = list,
    inheritance = inheritance,
    category = category,
    pathogenicity_mode = pathogenicity_mode
  )

  # generate object to return
  data
}


#* Get Upset Plot Data
#*
#* This endpoint retrieves data for generating an UpSet plot
#* showing the intersection between different databases.
#*
#* # `Details`
#* Retrieves data for generating an UpSet plot.
#*
#* # `Return`
#* Returns the data for the UpSet plot.
#*
#* @tag comparisons
#* @serializer json list(na="string")
#* 
#* @param fields Comma separated list of fields to include in the UpSet plot.
#* 
#* @get /api/comparisons/upset
function(res, fields = "") {
  # get data from database and filter
  ndd_database_comp_gene_list  <- pool %>%
    tbl("ndd_database_comparison_view") %>%
    collect()

  # split the fields input by comma
  if (fields != "") {
    fields <- str_split(str_replace_all(fields, fixed(" "), ""), ",")[[1]]
  } else {
    fields <- (ndd_database_comp_gene_list %>%
      select(list) %>%
      unique() %>%
      as.list())$list
  }

  # get data from database and filter
  comparison_upset_data  <- ndd_database_comp_gene_list %>%
    select(name = hgnc_id, sets = list) %>%
    unique() %>%
    filter(sets %in% fields) %>%
    group_by(name) %>%
    arrange(name) %>%
    mutate(sets = str_c(sets, collapse = ",")) %>%
    unique() %>%
    ungroup() %>%
    mutate(sets = strsplit(sets, ","))

  # generate object to return
  comparison_upset_data
}


#* Get Cosine Similarity Data
#*
#* This endpoint retrieves cosine similarity data between different
#* databases for plotting.
#*
#* # `Details`
#* Retrieves cosine similarity data between databases.
#*
#* # `Return`
#* Returns the cosine similarity data.
#*
#* @tag comparisons
#* @serializer json list(na="string")
#* 
#* @get /api/comparisons/similarity
function() {

  # get data from database, filter and restructure
  ndd_database_comparison_matrix  <- pool %>%
    tbl("ndd_database_comparison_view") %>%
    collect() %>%
    select(hgnc_id, list) %>%
    unique() %>%
    mutate(in_list = list) %>%
    pivot_wider(names_from = list, values_from = in_list) %>%
    select(-hgnc_id) %>%
    mutate_all(~ case_when(
        is.na(.) ~ 0,
        !is.na(.) ~ 1,
      )
    )

  # compute similarity matrix
  ndd_database_comp_sim <- cosine(ndd_database_comparison_matrix)
  ndd_database_comp_sim_melted <- melt(ndd_database_comp_sim) %>%
    select(x = Var1, y = Var2, value)

  # generate object to return
  ndd_database_comp_sim_melted

}


#* Browse NDD Genes Across Databases
#*
#* This endpoint retrieves a table showing the presence of NDD-associated
#* genes in different databases.
#*
#* # `Details`
#* Retrieves a table showing NDD-associated genes in different databases.
#*
#* # `Return`
#* Returns a table of NDD-associated genes.
#*
#* @tag comparisons
#* @serializer json list(na="string")
#* 
#* @param sort Output column to arrange output on.
#* @param filter Comma separated list of filters to apply.
#* @param fields Comma separated list of output columns.
#* @param page_after Cursor after which to show entries in pagination.
#* @param page_size Page size in cursor pagination.
#* @param fspec Fields for field specification in meta data response.
#* 
#* @get /api/comparisons/browse
function(req,
  res,
  sort = "symbol",
  filter = "",
  fields = "",
  `page_after` = "0",
  `page_size` = "10",
  fspec = "symbol,SysNDD,radboudumc_ID,gene2phenotype,panelapp,sfari,geisinger_DBD,omim_ndd,orphanet_id",
  format = "json") {
  # set serializers
  res$serializer <- serializers[[format]]

  # call the endpoint function generate_phenotype_entities
  comparisons_list <- generate_comparisons_list(sort,
    filter,
    fields,
    `page_after`,
    `page_size`,
    fspec)

  # if xlsx requested compute this and return
  if (format == "xlsx") {
    # generate creation date statistic for output
    creation_date <- strftime(as.POSIXlt(Sys.time(),
      "UTC",
      "%Y-%m-%dT%H:%M:%S"),
      "%Y-%m-%d_T%H-%M-%S")

    # generate base filename from api name
    base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
        str_replace_all("_api_", "")

    filename <- file.path(paste0(base_filename,
      "_",
      creation_date,
      ".xlsx"))

    # generate xlsx bin using helper function
    bin <- generate_xlsx_bin(comparisons_list, base_filename)

    # Return the binary contents
    as_attachment(bin, filename)
  } else {
    comparisons_list
  }
}

## Comparisons endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Analyses endpoints

#* Retrieve Available Functional Clustering Categories
#*
#* This endpoint fetches the available functional clustering categories
#* for genes, linking them to their respective sources.
#*
#* # `Details`
#* Retrieves functional clustering categories with source links.
#*
#* # `Return`
#* Returns a list of functional clustering categories and their source links.
#*
#* @tag analysis
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns functional clustering categories and source links.
#*
#* @get /api/analysis/functional_clustering
function() {

  # define link sources
  value <- c("COMPARTMENTS",
    "Component",
    "DISEASES",
    "Function",
    "HPO",
    "InterPro",
    "KEGG",
    "Keyword",
    "NetworkNeighborAL",
    "Pfam",
    "PMID",
    "Process",
    "RCTM",
    "SMART",
    "TISSUES",
    "WikiPathways")

  link <- c("https://www.ebi.ac.uk/QuickGO/term/",
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://disease-ontology.org/term/",
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://hpo.jax.org/app/browse/term/",
    "http://www.ebi.ac.uk/interpro/entry/InterPro/",
    "https://www.genome.jp/dbget-bin/www_bget?",
    "https://www.uniprot.org/keywords/",
    "https://string-db.org/cgi/network?input_query_species=9606&network_cluster_id=",
    "https://www.ebi.ac.uk/interpro/entry/pfam/",
    "https://www.ncbi.nlm.nih.gov/search/all/?term=",
    "https://www.ebi.ac.uk/QuickGO/term/",
    "https://reactome.org/content/detail/R-",
    "http://www.ebi.ac.uk/interpro/entry/smart/",
    "https://ontobee.org/ontology/BTO?iri=http://purl.obolibrary.org/obo/",
    "https://www.wikipathways.org/index.php/Pathway:")

  links <- tibble(value, link)

  # get data from database
  genes_from_entity_table <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    filter(ndd_phenotype == 1) %>%
    select(hgnc_id) %>%
    collect() %>%
    unique()

  functional_clusters <- gen_string_clust_obj_mem(
    genes_from_entity_table$hgnc_id)

  categories <- functional_clusters %>%
    select(term_enrichment) %>%
    unnest(cols = c(term_enrichment)) %>%
    select(category) %>%
    unique() %>%
    arrange(category) %>%
    mutate(text = case_when(
      nchar(category) <= 5 ~ category,
      nchar(category) > 5 ~ str_to_sentence(category)
    )) %>%
    select(value = category, text) %>%
    left_join(links, by = c("value"))

  # generate object to return
  list(categories = categories,
    clusters = functional_clusters)

}


#* Retrieve Phenotype Clustering Data
#*
#* This endpoint fetches data clusters of entities based on phenotypes
#* using Multiple Correspondence Analysis (MCA) and Hierarchical Clustering.
#*
#* # `Details`
#* Retrieves phenotype-based clusters of entities.
#*
#* # `Return`
#* Returns a list of entities grouped by phenotype clusters.
#*
#* @tag analysis
#* @serializer json list(na="string")
#*
#* @response 200 OK. Returns phenotype clustering data.
#*
#* @get /api/analysis/phenotype_clustering
function() {
  # define constants for filtering
  id_phenotype_ids <- c("HP:0001249",
    "HP:0001256",
    "HP:0002187",
    "HP:0002342",
    "HP:0006889",
    "HP:0010864")

  categories <- c("Definitive")

  # get data from database
  ndd_entity_view_tbl <- pool %>%
    tbl("ndd_entity_view") %>%
    collect()

  ndd_entity_review_tbl <- pool %>%
    tbl("ndd_entity_review") %>%
    collect() %>%
    filter(is_primary == 1) %>%
    select(review_id)

  ndd_review_phenotype_connect_tbl <- pool %>%
    tbl("ndd_review_phenotype_connect") %>%
    collect()

  modifier_list_tbl <- pool %>%
    tbl("modifier_list") %>%
    collect()

  phenotype_list_tbl <- pool %>%
    tbl("phenotype_list") %>%
    collect()

  # join tables and filter
  sysndd_db_phenotypes <- ndd_entity_view_tbl %>%
    left_join(ndd_review_phenotype_connect_tbl, by = c("entity_id")) %>%
    left_join(modifier_list_tbl, by = c("modifier_id")) %>%
    left_join(phenotype_list_tbl, by = c("phenotype_id")) %>%
    mutate(ndd_phenotype = case_when(
      ndd_phenotype == 1 ~ "Yes",
      ndd_phenotype == 0 ~ "No"
    )) %>%
    filter(ndd_phenotype == "Yes") %>%
    filter(category %in% categories) %>%
    filter(modifier_name == "present") %>%
    filter(review_id %in% ndd_entity_review_tbl$review_id) %>%
    select(entity_id,
      hpo_mode_of_inheritance_term_name,
      phenotype_id,
      HPO_term,
      hgnc_id) %>%
    group_by(entity_id) %>%
    mutate(phenotype_non_id_count =
      sum(!(phenotype_id %in% id_phenotype_ids))) %>%
    mutate(phenotype_id_count = sum(phenotype_id %in% id_phenotype_ids)) %>%
    ungroup() %>%
    unique()

  # convert to wide format
  sysndd_db_phenotypes_wider <- sysndd_db_phenotypes %>%
    mutate(present = "yes") %>%
    select(-phenotype_id) %>%
    pivot_wider(names_from = HPO_term, values_from = present) %>%
    group_by(hgnc_id) %>%
    mutate(gene_entity_count = n()) %>%
    ungroup() %>%
    relocate(gene_entity_count, .after = phenotype_id_count) %>%
    select(-hgnc_id)

  # convert to data frame
  sysndd_db_phenotypes_wider_df <- sysndd_db_phenotypes_wider %>%
    select(-entity_id) %>%
    as.data.frame()

  # transform rownames to entity_id
  row.names(sysndd_db_phenotypes_wider_df) <-
    sysndd_db_phenotypes_wider$entity_id

  # call cluster analysis function
  phenotype_clusters <- gen_mca_clust_obj_mem(
    sysndd_db_phenotypes_wider_df)

  # add back gene identifiers
  ndd_entity_view_tbl_sub <- ndd_entity_view_tbl %>%
    select(entity_id, hgnc_id, symbol)

  phenotype_clusters_identifiers <- phenotype_clusters %>%
  unnest(identifiers) %>%
  mutate(entity_id = as.integer(entity_id)) %>%
  left_join(ndd_entity_view_tbl_sub, by = c("entity_id")) %>%
  nest(identifiers = c(entity_id, hgnc_id, symbol))

  # return output
  phenotype_clusters_identifiers
}

## Analyses endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Hash endpoints

#* Create a Hash for a List of Identifiers
#*
#* This endpoint takes a list of identifiers, sorts and hashes them,
#* then saves and returns a hash link.
#*
#* # `Details`
#* Creates a hash link for a list of identifiers.
#*
#* # `Return`
#* Returns a hash link for the given list of identifiers.
#*
#* @tag hash
#* @serializer json list(na="string")
#*
#* @param json_data The list of identifiers to hash.
#* @param endpoint The endpoint to associate with the hash.
#*
#* @response 200 OK. Returns the created hash link.
#* @response 400 Bad Request. Missing required 'json_data' parameter.
#*
#* @post /api/hash/create
function(req, res, endpoint = "/api/gene") {

  # get data from POST body
  json_data <- req$argsBody$json_data

  if (is.null(json_data)) {
    res$status <- 400
    res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
    status = 400,
    message = paste0("Required 'json_data' ",
      "parameter not provided.")
    ))
    return(res)
  } else {
    # block to generate and post the hash
    response_hash <- post_db_hash(json_data,
     "symbol,hgnc_id,entity_id",
      endpoint)

    # return response
    return(response_hash)
  }
}

## Hash endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Search endpoints

#* Search Entity View by Multiple Columns
#*
#* This endpoint enables searching of the entity view by columns including
#* entity_id, hgnc_id, symbol, disease_ontology_id_version, and 
#* disease_ontology_name.
#*
#* # `Details`
#* Supports advanced searching with fuzzy matching.
#*
#* # `Return`
#* Returns a list of matching entities.
#*
#* @tag search
#* @serializer json list(na="string")
#*
#* @param searchterm The search query.
#* @param helper Logical flag to control output format.
#*
#* @response 200 OK. Returns the list of matching entities.
#*
#* @get /api/search/<searchterm>
function(searchterm, helper = TRUE) {
  # make sure helper input is logical
  helper <- as.logical(helper)

  searchterm <- URLdecode(searchterm) %>%
    str_squish()

  sysndd_db_entity_search <- pool %>%
    tbl("ndd_entity_view") %>%
    arrange(entity_id) %>%
    collect() %>%
    select(entity_id,
      hgnc_id,
      symbol,
      disease_ontology_id_version,
      disease_ontology_name) %>%
    mutate(entity = as.character(entity_id)) %>%
    pivot_longer(!entity_id, names_to = "search", values_to = "results") %>%
    mutate(search = str_replace(search, "entity", "entity_id")) %>%
    mutate(searchdist = stringdist(str_to_lower(results),
      str_to_lower(searchterm),
      method = "jw",
      p = 0.1)) %>%
    arrange(searchdist, results) %>%
    mutate(results_url = URLencode(results, reserved = TRUE)) %>%
    mutate(link = case_when(
      search == "hgnc_id" ~ paste0("/Genes/", results_url),
      search == "symbol" ~ paste0("/Genes/", results_url),
      search == "disease_ontology_id_version" ~ paste0("/Ontology/", results_url),
      search == "disease_ontology_name" ~ paste0("/Ontology/", results_url),
      search == "entity_id" ~ paste0("/Entities/", results_url)
    )) %>%
    select(-results_url)

  # compute filtered length with match < 0.1
  sysndd_db_entity_search_length <- sysndd_db_entity_search %>%
    filter(searchdist < 0.1) %>%
    tally()

  if (sysndd_db_entity_search_length$n > 10) {
    return_count <- sysndd_db_entity_search_length$n
  } else {
    return_count <- 10
  }

  # check if perfect match exists
  if (sysndd_db_entity_search$searchdist[1] == 0 &&
    is.na(suppressWarnings(as.integer(sysndd_db_entity_search$results[1])))) {
    sysndd_db_entity_search_return <- sysndd_db_entity_search %>%
      slice_head(n = 1)
  } else {
    sysndd_db_entity_search_return <- sysndd_db_entity_search %>%
      slice_head(n = return_count)
  }

  # change output by helper input to
  # unique values (helper = TRUE) or entities (helper = FALSE)
  if (helper) {
    sysndd_db_entity_search_return <- sysndd_db_entity_search_return %>%
      tidyr::nest(.by = c(results), .key = "values") %>%
      ungroup() %>%
      pivot_wider(id_cols = everything(), names_from = "results", values_from = "values")
  } else {
    sysndd_db_entity_search_return
  }

  # return output
  sysndd_db_entity_search_return
}


#* Search Disease Ontology by ID or Name
#*
#* This endpoint allows searching within the disease ontology set
#* by disease_ontology_id_version and disease_ontology_name.
#*
#* # `Details`
#* Supports advanced searching with fuzzy matching.
#*
#* # `Return`
#* Returns a list of matching disease ontology terms.
#*
#* @tag search
#* @serializer json list(na="string")
#*
#* @param searchterm The search query.
#* @param tree Logical flag to control output format.
#*
#* @response 200 OK. Returns the list of matching disease ontology terms.
#*
#* @get /api/search/ontology/<searchterm>
function(searchterm, tree = FALSE) {
  # make sure tree input is logical
  tree <- as.logical(tree)

  searchterm <- URLdecode(searchterm) %>%
    str_squish()

  do_set_search <- pool %>%
    tbl("search_disease_ontology_set") %>%
    filter(result %like% paste0("%", searchterm, "%")) %>%
    collect() %>%
    mutate(searchdist = stringdist(
      str_to_lower(result),
      str_to_lower(searchterm),
      method = "jw",
      p = 0.1)) %>%
    arrange(searchdist, result)

  # compute filtered length with match < 0.1
  do_set_search_length <- do_set_search %>%
    filter(searchdist < 0.1) %>%
    tally()

  if (do_set_search_length$n > 10) {
    return_count <- do_set_search_length$n
  } else {
    return_count <- 10
  }

  do_set_search_return <- do_set_search %>%
    slice_head(n = return_count)

  # the "tree" option allows output data to be formatted
  # as arrays for the treeselect library
  # do here means disease_ontology
  if (tree) {
    do_set_search_return_helper <- do_set_search_return %>%
      select(id = disease_ontology_id_version,
        label = result,
        disease_ontology_id_version,
        disease_ontology_id,
        disease_ontology_name,
        search,
        searchdist)
  } else {
    do_set_search_return_helper <- do_set_search_return %>%
      tidyr::nest(.by = c(results), .key = "values") %>%
      ungroup() %>%
      pivot_wider(id_cols = everything(), names_from = "result", values_from = "values")
  }

  # return output
  do_set_search_return_helper
}


#* Search Gene by HGNC ID or Symbol
#*
#* This endpoint enables searching within the gene set by hgnc_id and symbol.
#*
#* # `Details`
#* Supports advanced searching with fuzzy matching.
#*
#* # `Return`
#* Returns a list of matching genes.
#*
#* @tag search
#* @serializer json list(na="string")
#*
#* @param searchterm The search query.
#* @param tree Logical flag to control output format.
#*
#* @response 200 OK. Returns the list of matching genes.
#*
#* @get /api/search/gene/<searchterm>
function(searchterm, tree = FALSE) {
  # make sure tree input is logical
  tree <- as.logical(tree)

  searchterm <- URLdecode(searchterm) %>%
    str_squish()

  non_alt_loci_set_search <- pool %>%
    tbl("search_non_alt_loci_view") %>%
    filter(result %like% paste0("%", searchterm, "%")) %>%
    collect() %>%
    mutate(searchdist = stringdist(str_to_lower(result),
      str_to_lower(searchterm),
      method = "jw",
      p = 0.1)) %>%
    arrange(searchdist, result)

  # compute filtered length with match < 0.1
  non_alt_loci_set_search_length <- non_alt_loci_set_search %>%
    filter(searchdist < 0.1) %>%
    tally()

  if (non_alt_loci_set_search_length$n > 10) {
    return_count <- non_alt_loci_set_search_length$n
  } else {
    return_count <- 10
  }

  non_alt_loci_set_search_return <- non_alt_loci_set_search %>%
    slice_head(n = return_count)

  # the "tree" option allows output data to be formatted
  # as arrays for the treeselect library
  if (tree) {
    nal_set_search_return_helper <- non_alt_loci_set_search_return %>%
      select(id = hgnc_id, label = result, symbol, name, search, searchdist)
  } else {
    nal_set_search_return_helper <- non_alt_loci_set_search_return %>%
      tidyr::nest(.by = c(results), .key = "values") %>%
      ungroup() %>%
      pivot_wider(id_cols = everything(), names_from = "result", values_from = "values")
  }

  # return output
  nal_set_search_return_helper
}


#* Search Mode of Inheritance by Term Name or Term
#*
#* This endpoint allows searching within the mode of inheritance list by 
#* hpo_mode_of_inheritance_term_name and hpo_mode_of_inheritance_term.
#*
#* # `Details`
#* Supports advanced searching with fuzzy matching.
#*
#* # `Return`
#* Returns a list of matching mode of inheritance terms.
#*
#* @tag search
#* @serializer json list(na="string")
#*
#* @param searchterm The search query.
#* @param tree Logical flag to control output format.
#*
#* @response 200 OK. Returns the list of matching mode of inheritance terms.
#*
#* @get /api/search/inheritance/<searchterm>
function(searchterm, tree = FALSE) {
  # make sure tree input is logical
  tree <- as.logical(tree)

  searchterm <- URLdecode(searchterm) %>%
    str_squish()

  moi_list <- pool %>%
    tbl("search_mode_of_inheritance_list_view") %>%
    collect() %>%
    mutate(searchdist = 1)

  moi_list_search <- pool %>%
    tbl("search_mode_of_inheritance_list_view") %>%
    filter(result %like% paste0("%", searchterm, "%")) %>%
    collect() %>%
    mutate(searchdist = stringdist(str_to_lower(result),
      str_to_lower(searchterm),
      method = "jw",
      p = 0.1)) %>%
    arrange(searchdist, sort)

  # compute filtered length with match < 0.1
  moi_list_search_length <- moi_list_search %>%
    filter(searchdist < 0.1) %>%
    tally()

  if (moi_list_search_length$n > 10) {
    return_count <- moi_list_search_length$n
  } else {
    return_count <- 10
  }

  moi_list_search_return <- moi_list_search %>%
    slice_head(n = return_count)

  # the "tree" option allows output data to be
  # formatted as arrays for the treeselect library
  if (tree) {
    moi_list_search_return_helper <- moi_list_search_return %>%
      select(id = hpo_mode_of_inheritance_term,
        label = result,
        search,
        searchdist)
  } else {
    moi_list_search_return_helper <- moi_list_search_return %>%
      tidyr::nest(.by = c(results), .key = "values") %>%
      ungroup() %>%
      pivot_wider(id_cols = everything(), names_from = "result", values_from = "values")
  }

  # return output
  moi_list_search_return_helper
}

## Search endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## List endpoints

#* Get All Status Categories
#*
#* This endpoint retrieves a list of all status categories.
#*
#* # `Return`
#* Returns a list of status categories.
#*
#* @tag list
#* @serializer json list(na="string")
#*
#* @param tree Logical flag to control output format.
#*
#* @response 200 OK. Returns the list of status categories.
#*
#* @get /api/list/status
function(tree = FALSE) {
  # make sure tree input is logical
  tree <- as.logical(tree)

  status_list_collected <- pool %>%
    tbl("ndd_entity_status_categories_list") %>%
    arrange(category_id) %>%
    collect()

  # the "tree" option allows output data to be formatted
  # as arrays for the treeselect library
  # do short for disease_ontology
  if (tree) {
    status_list_return_helper <- status_list_collected
  } else {
    status_list_return_helper <- status_list_collected %>%
      tidyr::nest(.by = c(results), .key = "values") %>%
      ungroup() %>%
      pivot_wider(id_cols = everything(), names_from = "category", values_from = "values")
  }

  # return output
  status_list_return_helper
}


#* Get All Phenotypes
#*
#* This endpoint retrieves a list of all phenotypes.
#*
#* # `Return`
#* Returns a list of phenotypes.
#*
#* @tag list
#* @serializer json list(na="string")
#*
#* @param tree Logical flag to control output format.
#*
#* @response 200 OK. Returns the list of phenotypes.
#*
#* @get /api/list/phenotype
function(tree = FALSE) {
  # make sure tree input is logical
  tree <- as.logical(tree)

  # the "tree" option allows output data to be formatted as
  # arrays for the treeselect library
  # change output by tree input to simple table (tree = FALSE)
  # or treeselect compatible output with modifiers (tree = TRUE)
  if (tree) {
    modifier_list_collected <- pool %>%
      tbl("modifier_list") %>%
      filter(allowed_phenotype) %>%
      select(modifier_id, modifier_name) %>%
      arrange(modifier_id) %>%
      collect()

    phenotype_list_collected <- pool %>%
      tbl("phenotype_list") %>%
      select(phenotype_id, HPO_term, HPO_term_definition, HPO_term_synonyms) %>%
      arrange(HPO_term) %>%
      collect() %>%
      mutate(children = list(modifier_list_collected)) %>%
      unnest(children) %>%
      filter(modifier_id != 1) %>%
      mutate(id = paste0(modifier_id, "-", phenotype_id)) %>%
      mutate(label = paste0(modifier_name, ": ", HPO_term)) %>%
      select(-modifier_id, -modifier_name) %>%
      nest(data = c(id, label)) %>%
      mutate(phenotype_id = paste0("1-", phenotype_id)) %>%
      mutate(HPO_term = paste0("present: ", HPO_term)) %>%
      select(id = phenotype_id, label = HPO_term, children = data)
  } else {
    phenotype_list_collected <- pool %>%
      tbl("phenotype_list") %>%
      select(phenotype_id, HPO_term, HPO_term_definition, HPO_term_synonyms) %>%
      arrange(HPO_term) %>%
      collect()
  }

  # return output
  phenotype_list_collected
}


#* Get All Inheritance Terms
#*
#* This endpoint retrieves a list of all inheritance terms.
#*
#* # `Return`
#* Returns a list of inheritance terms.
#*
#* @tag list
#* @serializer json list(na="string")
#*
#* @param tree Logical flag to control output format.
#*
#* @response 200 OK. Returns the list of inheritance terms.
#*
#* @get /api/list/inheritance
function(tree = FALSE) {
  # make sure tree input is logical
  tree <- as.logical(tree)

  moi_list_collected <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    arrange(hpo_mode_of_inheritance_term) %>%
    collect() %>%
    filter(is_active == 1) %>%
    select(-is_active, -update_date)

  # the "tree" option allows output data to be formatted
  # as arrays for the treeselect library
  # moi short for mode of inheritance
  if (tree) {
    moi_list_return_helper <- moi_list_collected %>%
      select(id = hpo_mode_of_inheritance_term, label =
        hpo_mode_of_inheritance_term_name)
  } else {
    moi_list_return_helper <- moi_list_collected %>%
      tidyr::nest(.by = c(hpo_mode_of_inheritance_term), .key = "values") %>%
      ungroup() %>%
      pivot_wider(id_cols = everything(),
        names_from = "hpo_mode_of_inheritance_term",
        values_from = "values")
  }

  # return output
  moi_list_return_helper
}


#* Get All Variation Ontology Terms
#*
#* This endpoint retrieves a list of all variation ontology terms.
#*
#* # `Return`
#* Returns a list of variation ontology terms.
#*
#* @tag list
#* @serializer json list(na="string")
#*
#* @param tree Logical flag to control output format.
#*
#* @response 200 OK. Returns the list of variation ontology terms.
#*
#* @get /api/list/variation_ontology
function(tree = FALSE) {
  # make sure tree input is logical
  tree <- as.logical(tree)

  # the "tree" option allows output data to be formatted as
  # arrays for the treeselect library
  # change output by tree input to simple table (tree = FALSE)
  # or treeselect compatible output with modifiers (tree = TRUE)
  if (tree) {
    modifier_list_collected <- pool %>%
      tbl("modifier_list") %>%
      filter(allowed_variation) %>%
      select(modifier_id, modifier_name) %>%
      arrange(modifier_id) %>%
      collect()

    variation_ontology_list_coll <- pool %>%
      tbl("variation_ontology_list") %>%
      filter(is_active) %>%
      select(vario_id, vario_name, definition, sort) %>%
      arrange(`sort`) %>%
      collect() %>%
      select(-`sort`) %>%
      mutate(children = list(modifier_list_collected)) %>%
      unnest(children) %>%
      filter(modifier_id != 1) %>%
      mutate(id = paste0(modifier_id, "-", vario_id)) %>%
      mutate(label = paste0(modifier_name, ": ", vario_name)) %>%
      select(-modifier_id, -modifier_name) %>%
      nest(data = c(id, label)) %>%
      mutate(vario_id = paste0("1-", vario_id)) %>%
      mutate(vario_name = paste0("present: ", vario_name)) %>%
      select(id = vario_id, label = vario_name, children = data)
  } else {
    variation_ontology_list_coll <- pool %>%
      tbl("variation_ontology_list") %>%
      select(vario_id, vario_name, definition, sort) %>%
      arrange(`sort`) %>%
      collect() %>%
      select(-`sort`)
  }

  # return output
  variation_ontology_list_coll
}

## List endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## External endpoints

#* Submit URL to Internet Archive
#*
#* This endpoint takes a sysndd URL and submits it to the Internet Archive for archiving.
#*
#* # `Details`
#* Validates the provided URL against the base URL of the archive.
#*
#* # `Return`
#* Returns the status of the archiving operation.
#*
#* @tag external
#* @serializer json list(na="string")
#*
#* @param parameter_url The URL to be archived.
#* @param capture_screenshot Flag to capture a screenshot during archiving.
#*
#* @response 200 OK. URL successfully archived.
#* @response 400 Bad Request. Invalid or missing URL.
#*
#* @get /api/external/internet_archive
function(req, res, parameter_url, capture_screenshot = "on") {

  # check if provided URL is valid
  url_valid <- str_detect(parameter_url, dw$archive_base_url)

  if (!url_valid) {
    res$status <- 400
    res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
    status = 400,
    message = paste0("Required 'url' ",
      "parameter not provided or not valid.")
    ))
    return(res)
  } else {
    # block to generate and post the external archive request
    response_archive <- post_url_archive(parameter_url,
      capture_screenshot)

    # return response
    return(response_archive)
  }
}

## External endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Logging section

#* Get Paginated Log Files
#*
#* This endpoint returns paginated log files from a specified folder.
#*
#* # `Details`
#* This is a plumber endpoint function that reads log files using the `read_log_files` 
#* function, applies filtering and pagination, and returns the data as a JSON response. 
#* The function takes input parameters for folder path, sorting, filtering, and field 
#* selection, and uses cursor pagination to generate links to previous and next pages.
#*
#* # `Return`
#* A cursor pagination object containing a list of log file entries.
#*
#* @tag logging
#* @serializer json list(na="string")
#*
#* @param folder_path:str Path to the folder containing log files.
#* @param sort:str Column to arrange output on.
#* @param filter:str Comma separated list of filters to apply.
#* @param fields:str Comma separated list of output columns.
#* @param page_after:str Cursor after which entries are shown.
#* @param page_size:str Page size in cursor pagination.
#* @param fspec:str Fields to generate field specification for.
#*
#* @response 200 OK. A cursor pagination object with links, meta and data (log entries).
#* @response 500 Internal server error.
#*
#* @get /api/logs
function(req,
         res,
         folder_path = "logs",
         sort = "row_id",
         filter = "",
         fields = "",
         `page_after` = 0,
         `page_size` = "10",
         fspec = "row_id,remote_addr,http_user_agent,http_host,request_method,path_info,query_string,postbody,status,duration,filename,last_modified",
         format = "json") {
    # Check if the user_role is set and if the user is an Administrator
    if (is.null(req$user_role) || req$user_role != "Administrator") {
      res$status <- 403 # Forbidden
      return(list(error = "Access forbidden. Only administrators can access logs."))
    }

    # Set serializers
    res$serializer <- serializers[[format]]

    # Start time calculation
    start_time <- Sys.time()

    # Read log files
    logs_raw <- read_log_files_mem(folder_path)

    # Generate sort expression
    sort_exprs <- generate_sort_expressions(sort, unique_id = "row_id")

    # Generate filter expression
    filter_exprs <- generate_filter_expressions(filter)

    # Apply sorting and filtering
    logs_table <- logs_raw %>%
      arrange(!!!rlang::parse_exprs(sort_exprs)) %>%
      filter(!!!rlang::parse_exprs(filter_exprs))

    # Select fields
    logs_table <- select_tibble_fields(logs_table, fields, "row_id")

    # Apply pagination
    log_pagination_info <- generate_cursor_pag_inf(logs_table, `page_size`, `page_after`, "row_id")

    # Generate field specifications if needed
    if (fspec != "") {
      # use the helper generate_tibble_fspec to
      # generate fields specs from a tibble
      # first for the unfiltered and not subset table
      logs_raw_fspec <- generate_tibble_fspec_mem(logs_raw,
        fspec)
      # then for the filtered/ subset one
      logs_table <- generate_tibble_fspec_mem(
        logs_table,
        fspec)
      # assign the second to the first as filtered
      logs_raw_fspec$fspec$count_filtered <-
        logs_raw_fspec$fspec$count
    }

    # Compute execution time
    end_time <- Sys.time()
    execution_time <- as.character(paste0(round(end_time - start_time, 2), " secs"))

    # add columns to the meta information from
    # generate_cursor_pag_inf function return
    meta <- log_pagination_info$meta %>%
      add_column(tibble::as_tibble(list("sort" = sort,
        "filter" = filter,
        "fields" = fields,
        "fspec" = logs_raw_fspec,
        "executionTime" = execution_time)))

    # add host, port and other information to links from
    # the link information from generate_cursor_pag_inf function return
    links <- log_pagination_info$links %>%
        pivot_longer(everything(), names_to = "type", values_to = "link") %>%
      mutate(link = case_when(
        link != "null" ~ paste0(
          dw$api_base_url,
          "/api/entity?sort=",
          sort,
          ifelse(filter != "", paste0("&filter=", filter), ""),
          ifelse(fields != "", paste0("&fields=", fields), ""),
          link),
        link == "null" ~ "null"
      )) %>%
        pivot_wider(id_cols = everything(), names_from = "type", values_from = "link")

    # Prepare response
    response <- list(
        links = links,
        meta = meta,
        data = log_pagination_info$data
    )

    # if xlsx requested compute this and return
    if (format == "xlsx") {
      # generate creation date statistic for output
      creation_date <- strftime(as.POSIXlt(Sys.time(),
        "UTC",
        "%Y-%m-%dT%H:%M:%S"),
        "%Y-%m-%d_T%H-%M-%S")

      # generate base filename from api name
      base_filename <- str_replace_all(req$PATH_INFO, "\\/", "_") %>%
          str_replace_all("_api_", "")

      filename <- file.path(paste0(base_filename,
        "_",
        creation_date,
        ".xlsx"))

      # generate xlsx bin using helper function
      bin <- generate_xlsx_bin(response, base_filename)

      # Return the binary contents
      as_attachment(bin, filename)
    } else {
      response
    }
}

## Logging section
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## User endpoint section

#* Retrieves a summary table of users based on role permissions.
#*
#* # `Details`
#* This endpoint fetches a table containing summary information about users.
#* The table includes user details like ID, name, email, etc. Administrators
#* have access to all users, while Curators can only see unapproved users.
#*
#* # `Return`
#* A JSON object containing the user table.
#* For unauthorized or forbidden access, a status code and error message
#* are returned.
#*
#* @tag user
#* @serializer json list(na="string")
#* @get /api/user/table
function(req, res) {

  user <- req$user_id

  # first check rights
  if (length(user) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (req$user_role %in% c("Administrator")) {

    user_table <- pool %>%
      tbl("user") %>%
      select(user_id,
        user_name,
        email,
        orcid,
        first_name,
        family_name,
        comment,
        terms_agreed,
        created_at,
        user_role,
        approved) %>%
      collect()

    # return tibble
    user_table

  } else if (req$user_role %in% c("Curator")) {

    user_table <- pool %>%
      tbl("user") %>%
      select(user_id,
        user_name,
        email,
        orcid,
        first_name,
        family_name,
        comment,
        terms_agreed,
        created_at,
        user_role,
        approved) %>%
      filter(approved == 0) %>%
      collect()

    # return tibble
    user_table

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Read access forbidden."))
  }
}


#* Retrieves count statistics of all contributions for a specified user.
#*
#* # `Details`
#* This endpoint fetches the count of active reviews and active status 
#* contributions for a given user. Accessible by Administrators, Curators, 
#* and Reviewers.
#*
#* # `Return`
#* A JSON object containing user ID, count of active status, and count of
#* active reviews.
#* For unauthorized or forbidden access, a status code and error message
#* are returned.
#*
#* @tag user
#* @serializer json list(na="string")
#* @get /api/user/<user_id>/contributions
function(req, res, user_id) {

  user_requested <- user_id
  user <- req$user_id

  # first check rights
  if (length(user) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (req$user_role %in% c("Administrator", "Curator", "Reviewer")) {

  active_user_reviews <- pool %>%
    tbl("ndd_entity_review") %>%
    filter(is_primary == 1) %>%
    filter(review_user_id == user_requested) %>%
    select(review_id) %>%
    collect() %>%
    tally() %>%
    select(active_reviews = n)

  active_user_status <- pool %>%
    tbl("ndd_entity_status") %>%
    filter(is_active == 1) %>%
    filter(status_user_id == user_requested) %>%
    select(status_id) %>%
    collect() %>%
    tally() %>%
    select(active_status = n)

  # generate object to return
  list(user_id = user_requested,
    active_status = active_user_status$active_status,
    active_reviews = active_user_reviews$active_reviews)

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Read access forbidden."))
  }
}


#* Manages the approval status of a user application.
#*
#* # `Details`
#* This endpoint allows Administrators and Curators to approve or reject
#* user applications. If approved, a password is generated and an email
#* is sent to the user.
#*
#* # `Input`
#* - user_id: (integer) ID of the user whose application is to be managed.
#* - status_approval: (boolean) Approval status to set.
#*
#* # `Return`
#* A JSON object containing the outcome of the approval process.
#* For unauthorized or forbidden access, or if the user does not exist,
#* a status code and error message are returned.
#*
#* @tag user
#* @serializer json list(na="string")
#* @put /api/user/approval
function(req, res, user_id = 0, status_approval = FALSE) {

  user <- req$user_id

  # make sure user_id_approval input is integer
  user_id_approval <- as.integer(user_id)

  # make sure status_approval input is logical
  status_approval <- as.logical(status_approval)

  #check if user_id_approval exists and is not already approved
  user_table <- pool %>%
    tbl("user") %>%
    select(user_id, approved, first_name, family_name, email) %>%
    filter(user_id == user_id_approval) %>%
    collect()
  user_id_approval_exists <- as.logical(length(user_table$user_id))
  user_id_approval_approved <- as.logical(user_table$approved[1])

  # first check rights
  if (length(user) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (req$user_role %in% c("Administrator", "Curator") &&
      !user_id_approval_exists) {

    res$status <- 409 # Conflict
    return(list(error = "User account does not exist."))

  } else if (req$user_role %in% c("Administrator", "Curator") &&
      user_id_approval_exists &&
      user_id_approval_approved) {

    res$status <- 409 # Conflict
    return(list(error = "User account already active."))

  } else if (req$user_role %in% c("Administrator", "Curator") &&
      user_id_approval_exists &&
      !user_id_approval_approved) {

    if (status_approval) {
      # generate password
      user_password <- random_password()

      user_initials <- generate_initials(
        user_table$first_name,
        user_table$family_name)

      # connect to database, put approval for user application then disconnect
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port)

      dbExecute(sysndd_db,
        paste0("UPDATE user SET approved = 1 WHERE user_id = ",
          user_id_approval,
          ";"))

      dbExecute(sysndd_db,
        paste0("UPDATE user SET password = '",
          user_password, "' WHERE user_id = ",
          user_id_approval,
          ";"))

      dbExecute(sysndd_db,
        paste0("UPDATE user SET abbreviation = '",
          user_initials,
          "' WHERE user_id = ",
          user_id_approval,
          ";"))

      dbDisconnect(sysndd_db)

      # send mail
      # TODO: change blind copy curator mail address to a constant in config
      res <- send_noreply_email(c(
         "Your registration for sysndd.org has been approved by a curator.",
         "Your password (please change after first login):",
         user_password),
         "Account approved for SysNDD.org",
         user_table$email,
         "curator@sysndd.org"
        )
    } else {
      # connect to database, delete application then disconnect
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port)

      dbExecute(sysndd_db,
        paste0("DELETE FROM user WHERE user_id = ",
          user_id_approval,
          ";"))

      dbDisconnect(sysndd_db)
    }
  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Read access forbidden."))
  }
}


#* Allows administrators to change the roles of users.
#*
#* # `Details`
#* The role of a specified user can be changed by administrators.
#* Curators can only change roles to a subset of allowed roles.
#*
#* # `Input`
#* - user_id: (integer) The ID of the user whose role needs to be changed.
#* - role_assigned: (string) The role to assign to the user.
#*
#* @tag user
#* @put /api/user/change_role
function(req, res, user_id, role_assigned = "Viewer") {
  user <- req$user_id
  user_id_role <- as.integer(user_id)
  role_assigned <- as.character(role_assigned)

  # first check rights
  if (length(user) == 0) {
    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))
  } else if (req$user_role %in% c("Administrator")) {
    # connect to database and perform update query then disconnect
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port)

    dbExecute(sysndd_db,
      paste0("UPDATE user SET user_role = '",
        role_assigned,
        "' WHERE user_id = ",
        user_id_role,
        ";"))

    dbDisconnect(sysndd_db)

  } else if (req$user_role %in% c("Curator") &&
      role_assigned %in% c("Curator", "Reviewer", "Viewer")) {
    # connect to database and perform update query then disconnect
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port)

    dbExecute(sysndd_db,
    paste0("UPDATE user SET user_role = '",
      role_assigned,
      "' WHERE user_id = ",
      user_id_role,
      ";"))

    dbDisconnect(sysndd_db)

  } else if (req$user_role %in% c("Curator") &&
      role_assigned %in% c("Administrator")) {
    res$status <- 403 # Forbidden
    return(list(error = "Insufficient rights."))
  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Write access forbidden."))
  }
}


#* Retrieves a list of all available user roles.
#*
#* # `Details`
#* Administrators can view all roles. Curators can view all roles except "Administrator".
#*
#* # `Return`
#* A list of available user roles.
#*
#* @tag user
#* @get /api/user/role_list
function(req, res) {

  user <- req$user_id

  # first check rights
  if (length(user) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (req$user_role %in% c("Administrator")) {

    role_list <- tibble::as_tibble(user_status_allowed) %>%
      select(role = value)
    role_list

  } else if (req$user_role %in% c("Curator")) {

    role_list <- tibble::as_tibble(user_status_allowed) %>%
      select(role = value) %>%
      filter(role != "Administrator")
    role_list

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Read access forbidden."))
  }
}


#* Retrieves a list of users based on their roles.
#*
#* # `Details`
#* Administrators and Curators can retrieve a list of users filtered by roles.
#* The input roles should be comma-separated.
#*
#* # `Return`
#* A list of users filtered by roles.
#*
#* @tag user
#* @get /api/user/list
function(req, res, roles = "Viewer") {

  user <- req$user_id

  # split the roles input by comma and check if roles are in the allowed roles
  roles_list <- str_trim(str_split(str_squish(roles), ",")[[1]])

  # check if received roles are in allowed roles
  roles_allowed_check <- all(roles_list %in% user_status_allowed)

  if (!roles_allowed_check) {
    res$status <- 400
    res$body <- jsonlite::toJSON(auto_unbox = TRUE, list(
    status = 400,
    message = paste0("Some of the submitted roles ",
      "are not in the allowed roles list.")
    ))
    return(res)
  }

  # first check rights
  if (length(user) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (req$user_role %in% c("Administrator", "Curator")) {

    user_table_roles <- pool %>%
      tbl("user") %>%
      filter(approved == 1) %>%
      filter(user_role %in% roles_list) %>%
      select(user_id, user_name, user_role) %>%
      collect()
    user_table_roles

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Read access forbidden."))
  }
}


#* Allows a user or an administrator to change the user's password.
#*
#* # `Details`
#* Validates the old password and checks if the new password satisfies the criteria.
#* Then updates the password in the database.
#*
#* # `Return`
#* A status message indicating the outcome.
#*
#* @tag user
#* @put /api/user/password/update
function(
  req,
  res,
  user_id_pass_change = 0,
  old_pass = "",
  new_pass_1 = "",
  new_pass_2 = "") {

  user <- req$user_id
  user_id_pass_change <- as.integer(user_id_pass_change)

  #get user data from database table
  user_table <- pool %>%
    tbl("user") %>%
    select(user_id,
      user_name,
      password,
      approved,
      first_name,
      family_name,
      email) %>%
    filter(user_id == user_id_pass_change) %>%
    collect()

  #check if user_id_pass_change exists
  user_id_pass_change_exists <- as.logical(length(user_table$user_id))
  user_id_pass_change_approved <- as.logical(user_table$approved[1])

  #check if passwords match and the new password satisfies minimal criteria
  old_pass_match <- user_table$password[1] == old_pass
  new_pass_match_and_valid <- (new_pass_1 == new_pass_2) &&
    (new_pass_1 != old_pass) &&
    nchar(new_pass_1) > 7 &&
    grepl("[a-z]", new_pass_1) &&
    grepl("[A-Z]", new_pass_1) &&
    grepl("\\d", new_pass_1) &&
    grepl("[!@#$%^&*]", new_pass_1)

  # first check rights
  if (length(user) == 0) {

    res$status <- 401 # Unauthorized
    return(list(error = "Please authenticate."))

  } else if (
    (req$user_role %in% c("Administrator") || user == user_id_pass_change) &&
    !user_id_pass_change_exists &&
    (old_pass_match || req$user_role %in% c("Administrator")) &&
    new_pass_match_and_valid) {

    res$status <- 409 # Conflict
    return(list(error = "User account does not exist."))

  } else if (
    (req$user_role %in% c("Administrator") || user == user_id_pass_change) &&
    user_id_pass_change_exists && !user_id_pass_change_approved &&
    (old_pass_match || req$user_role %in% c("Administrator")) &&
    new_pass_match_and_valid) {

    res$status <- 409 # Conflict
    return(list(error = "User account not approved."))

  } else if (
    (req$user_role %in% c("Administrator") || user == user_id_pass_change) &&
    (!(old_pass_match ||
      req$user_role %in% c("Administrator")) ||
      !new_pass_match_and_valid)) {

    res$status <- 409 # Conflict
    return(list(error = "Password input problem."))

  } else if (
    (req$user_role %in% c("Administrator") || user == user_id_pass_change) &&
    user_id_pass_change_exists &&
    user_id_pass_change_approved &&
    (old_pass_match || req$user_role %in% c("Administrator")) &&
    new_pass_match_and_valid) {

    # connect to database, put approval for user application then disconnect
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port)

    dbExecute(sysndd_db,
      paste0("UPDATE user SET password = '",
        new_pass_1,
        "' WHERE user_id = ",
        user_id_pass_change,
        ";"))

    dbDisconnect(sysndd_db)

    res$status <- 201 # Created
    return(list(message = "Password successfully changed."))

  } else {
    res$status <- 403 # Forbidden
    return(list(error = "Read access forbidden."))
  }
}


#* Allows a user or an administrator to change the user's password.
#*
#* # `Details`
#* Validates the old password and checks if the new password satisfies the criteria.
#* Then updates the password in the database.
#*
#* # `Return`
#* A status message indicating the outcome.
#*
#* @tag user
#* @put /api/user/password/update
function(req, res, email_request = "") {

  user_table <- pool %>%
      tbl("user") %>%
      collect()

  # first validate email
  if (!is_valid_email(email_request)) {

    res$status <- 400 # Bad Request
    return(list(error = "Invalid Parameter Value Error."))

  } else if (!(email_request %in% user_table$email)) {
    res$status <- 200 # OK
    res <- "Request mail send!"
  } else if ((email_request %in% user_table$email)) {

    email_user <- str_to_lower(toString(email_request))

    #get user data from database table
    user_table <- user_table %>%
      mutate(email_lower = str_to_lower(email)) %>%
      filter(email_lower == email_user) %>%
      mutate(hash = toString(md5(paste0(dw$salt, password)))) %>%
      select(user_id, user_name, hash, email)

    # extract user_id by mail
    user_id_from_email <- user_table$user_id

    # request time
    timestamp_request <- Sys.time()

    # convert to timestamp
    timestamp_iat <- as.integer(timestamp_request)
    timestamp_exp <- as.integer(timestamp_request) + dw$refresh

    # load secret and convert to raw
    key <- charToRaw(dw$secret)

    # connect to database, put timestamp of request password reset
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port)

    dbExecute(sysndd_db,
      paste0("UPDATE user SET password_reset_date = '",
        timestamp_request,
        "' WHERE user_id = ",
        user_id_from_email[1],
        ";"))

    dbDisconnect(sysndd_db)

    claim <- jwt_claim(user_id = user_table$user_id,
      user_name = user_table$user_name,
      email = user_table$email,
      hash = user_table$hash,
      iat = timestamp_iat,
      exp = timestamp_exp)

    jwt <- jwt_encode_hmac(claim, secret = key)
    reset_url <- paste0(dw$base_url, "/PasswordReset/", jwt)

    # send mail
    res$status <- 200 # OK
    res <- send_noreply_email(c(
       "We received a password reset for your account",
       "at sysndd.org. Use this link to reset:",
       reset_url),
       "Your password reset request for SysNDD.org",
       user_table$email
      )
  } else {
    res$status <- 401 # Unauthorized
    return(list(error = "Error or unauthorized."))
  }
}


#* @tag user
#* does password reset
#* @get /api/user/password/reset/change
function(req, res, new_pass_1 = "", new_pass_2 = "") {

  # load jwt from header
  jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")

  # load secret and convert to raw
  key <- charToRaw(dw$secret)

  user_jwt <- jwt_decode_hmac(jwt, secret = key)
  user_jwt$token_expired <- (user_jwt$exp < as.numeric(Sys.time()))

  if (is.null(jwt) || user_jwt$token_expired) {
    res$status <- 401 # Unauthorized
    return(list(error = "Reset token expired."))
  } else {
    #get user data from database table
    user_table <- pool %>%
      tbl("user") %>%
      collect() %>%
      filter(user_id == user_jwt$user_id) %>%
      mutate(hash = toString(md5(paste0(dw$salt, password)))) %>%
      mutate(timestamp_iat = as.integer(password_reset_date)) %>%
      mutate(timestamp_exp = as.integer(password_reset_date) + dw$refresh) %>%
      select(user_id, user_name, hash, email, timestamp_iat, timestamp_exp)

    # compute JWT check
    claim_check <- jwt_claim(user_id = user_table$user_id,
      user_name = user_table$user_name,
      email = user_table$email,
      hash = user_table$hash,
      iat = user_table$timestamp_iat,
      exp = user_table$timestamp_exp)

    jwt_check <- jwt_encode_hmac(claim_check, secret = key)
    jwt_match <- (jwt == jwt_check)

    # check if passwords match and the new password satisfies minimal criteria
    new_pass_match_and_valid <- (new_pass_1 == new_pass_2) &&
      nchar(new_pass_1) > 7 &&
      grepl("[a-z]", new_pass_1) &&
      grepl("[A-Z]", new_pass_1) &&
      grepl("\\d", new_pass_1) &&
      grepl("[!@#$%^&*]", new_pass_1)

    # connect to database and change password
    # if criteria fullfilled, remove time to invalidate JWT
    if (jwt_match && new_pass_match_and_valid) {
      # connect to database, put approval for user application then disconnect
      sysndd_db <- dbConnect(RMariaDB::MariaDB(),
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port)

      dbExecute(sysndd_db,
        paste0("UPDATE user SET password = '",
          new_pass_1,
          "' WHERE user_id = ",
          user_jwt$user_id,
          ";"))

      dbExecute(sysndd_db,
        paste0("UPDATE user SET password_reset_date = NULL WHERE user_id = ",
          user_jwt$user_id,
          ";"))

      dbDisconnect(sysndd_db)

      res$status <- 201 # Created
      return(list(message = "Password successfully changed."))
    } else {
      res$status <- 409 # Conflict
      return(list(error = "Password or JWT input problem."))
    }
  }
}


#* Deletes a user from the system.
#*
#* # `Details`
#* This endpoint allows Administrators to delete a user from the database.
#* It checks for administrator role, validates the existence of the user, and then proceeds to delete the user.
#* The operation is logged for audit purposes.
#*
#* # `Input`
#* - `user_id`: (integer) The ID of the user to be deleted.
#*
#* # `Return`
#* A JSON object containing the status of the operation. In case of success, a confirmation message is returned.
#* For unauthorized access, incorrect input, or internal errors, a corresponding status code and error message are returned.
#*
#* @tag user
#* @serializer json list(na="string")
#* @delete /api/user/delete
function(req, res, user_id) {
  user_id <- as.integer(user_id)

  # Verify administrator access
  if (req$user_role != "Administrator") {
    res$status <- 403 # Forbidden
    return(list(error = "Administrative privileges required for this action."))
  }

  # Validate user_id input
  if (!is.numeric(user_id) || user_id <= 0) {
    res$status <- 400 # Bad Request
    return(list(error = "Invalid user_id provided."))
  }

  # Connect to the database
  sysndd_db <- dbConnect(RMariaDB::MariaDB(),
    dbname = dw$dbname,
    user = dw$user,
    password = dw$password,
    server = dw$server,
    host = dw$host,
    port = dw$port)

  # Check if the user exists
  exist_result <- dbGetQuery(sysndd_db, paste0("SELECT COUNT(*) as count FROM user WHERE user_id = ", user_id, ";"))
  if (exist_result$count == 0) {
    dbDisconnect(sysndd_db)
    res$status <- 404 # Not Found
    return(list(error = "User not found."))
  }

  # Prepare and execute the delete query
  delete_result <- tryCatch({
    dbExecute(sysndd_db, paste0("DELETE FROM user WHERE user_id = ", user_id, ";"))
  }, error = function(e) {
    NULL
  })

  # Disconnect from the database
  dbDisconnect(sysndd_db)

  # Check if the delete was successful
  if (is.null(delete_result)) {
    res$status <- 500 # Internal Server Error
    return(list(error = "Failed to delete user."))
  }

  list(message = "User successfully deleted.")
}


#* Updates the details of an existing user.
#*
#* # `Details`
#* This endpoint allows Administrators to modify user attributes. It accepts a JSON object containing
#* the user attributes to be updated. The `user_id` is required to identify the user, and at least one
#* other attribute must be provided for the update.
#*
#* # `Input`
#* - `user_json`: (JSON object) A JSON object representing the user attributes to be updated.
#*    Example: `{"user_id": 2, "email": "newemail@example.com", "first_name": "John", "family_name": "Doe"}`
#*
#* # `Return`
#* A JSON object containing the outcome of the update process.
#*
#* @tag user
#* @serializer json list(na="string")
#* @accept json
#* @put /api/user/update
function(req, res) {

  # Check if the user has admin privileges
  if (req$user_role != "Administrator") {
    res$status <- 403 # Forbidden
    return(list(error = "Administrative privileges required for this action."))
  }

  # Parse the JSON payload from the request
  user_details <- req$argsBody$user_details

  # Check for required user_id in the payload
  if (is.null(user_details$user_id)) {
    res$status <- 400 # Bad Request
    return(list(error = "The user_id field is required."))
  }

  # Connect to the database
  sysndd_db <- dbConnect(RMariaDB::MariaDB(),
    dbname = dw$dbname,
    user = dw$user,
    password = dw$password,
    server = dw$server,
    host = dw$host,
    port = dw$port)

  # Prepare the update query, excluding user_id which should not be modified
  fields_to_update <- names(user_details)[names(user_details) != "user_id"]
  set_clause <- paste(
    sapply(fields_to_update, function(field) {
      paste0(field, " = '", user_details[[field]], "'")
    }, USE.NAMES = FALSE),
    collapse = ", "
  )

  # Construct the full SQL update query
  query <- sprintf("UPDATE user SET %s WHERE user_id = %d;", set_clause, user_details[["user_id"]])

  # Execute the update query
  result <- tryCatch({
    dbExecute(sysndd_db, query)
  }, error = function(e) {
    list(error = e$message)
  })

  # Disconnect from the database
  dbDisconnect(sysndd_db)

  # Check if the update was successful
  if (is.list(result) && !is.null(result$error)) {
    res$status <- 500 # Internal Server Error
    return(list(error = "Failed to update user details: ", result$error))
  }

  list(message = "User details updated successfully.")
}

## User endpoint section
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Authentication section

# TODO: add signup data example
#* User Signup
#*
#* This endpoint is responsible for managing user signups. It validates the
#* provided signup data and, if valid, adds the new user to the database. It
#* then sends an email to the user to notify them of their successful signup.
#*
#* # `Details`
#* This is a Plumber endpoint function that handles user signups. It validates
#* the user's provided information, such as username, first name, family name,
#* email, ORCID, comment, and terms agreement. If all information is valid, the
#* function adds the new user to the user database and sends a confirmation
#* email to the user. If any of the provided information is not valid, the
#* function returns an error.
#*
#* # `Return`
#* If successful, the function does not return anything to the client but adds
#* the new user to the database and sends a confirmation email to the user. If
#* unsuccessful, it returns an error message.
#*
#* @tag authentication
#* @serializer json list(na="string")
#*
#* @param signup_data: The signup data provided by the user, in JSON format. It
#*             should include the user's username, first name, family name,
#*             email, ORCID, comment, and terms agreement.
#*
#* @response 200 OK. The signup was successful. The user is added to the
#*             database and a confirmation email is sent to the user.
#* @response 404 Not Found. An error message indicating that the provided
#*             signup data was not valid.
#*
#* @get /api/auth/signup
function(signup_data) {
  user <- tibble::as_tibble(fromJSON(signup_data)) %>%
      mutate(terms_agreed = case_when(
        terms_agreed == "accepted" ~ "1",
        terms_agreed != "accepted" ~ "0"
      )) %>%
    select(user_name,
      first_name,
      family_name,
      email, orcid,
      comment,
      terms_agreed)

  input_validation <- pivot_longer(user, cols = everything()) %>%
      mutate(valid = case_when(
        name == "user_name" ~ (nchar(value) >= 5 & nchar(value) <= 20),
        name == "first_name" ~ (nchar(value) >= 2 & nchar(value) <= 50),
        name == "family_name" ~ (nchar(value) >= 2 & nchar(value) <= 50),
        name == "email" ~ str_detect(value, regex(".+@.+\\..+", dotall = TRUE)),
        name == "orcid" ~ str_detect(value,
          regex("^(([0-9]{4})-){3}[0-9]{3}[0-9X]$",
          dotall = TRUE)),
        name == "comment" ~ (nchar(value) >= 10 & nchar(value) <= 250),
        name == "terms_agreed" ~ (value == "1")
      )) %>%
      mutate(all = "1") %>%
      select(all, valid) %>%
      group_by(all) %>%
      summarize(valid = as.logical(prod(valid))) %>%
      ungroup() %>%
      select(valid)

  if (input_validation$valid) {

    # connect to database
    sysndd_db <- dbConnect(RMariaDB::MariaDB(),
      dbname = dw$dbname,
      user = dw$user,
      password = dw$password,
      server = dw$server,
      host = dw$host,
      port = dw$port)

    dbAppendTable(sysndd_db, "user", user)
    dbDisconnect(sysndd_db)

    # send mail
    # TODO: change blind copy curator mail address to a constant in config
    res <- send_noreply_email(c(
       "Your registration request for sysndd.org has been send to the curators",
       "who will review it soon. Information provided:",
       user),
       "Your registration request to SysNDD.org",
       user$email,
       "curator@sysndd.org"
      )

  } else {
    res$status <- 404
    res$body <- "Please provide valid registration data."
    res
  }
}


#* Authenticate a User with Login
#*
#* This endpoint is responsible for authenticating a user using their username
#* and password. If the credentials match a record in the database and the
#* account is approved, the function returns a JWT; otherwise, it returns an
#* error.
#*
#* # `Details`
#* This is a Plumber endpoint function that uses JWT for user authentication.
#* JWT is a compact, URL-safe means of representing claims to be transferred
#* between two parties. The claims in a JWT are encoded as a JSON object that
#* is used as the payload of a JSON Web Signature (JWS) structure enabling the
#* claims to be digitally signed or integrity protected with a Message
#* Authentication Code (MAC) and/or encrypted.
#*
#* The function checks if the provided username and password are valid. If
#* valid, it checks if the credentials match an approved account in the
#* database. If a match is found, the function generates a JWT and returns it.
#* If no match is found or if the account is not approved, the function returns
#* an error.
#*
#* # `Return`
#* If successful, the function returns a JWT. If unsuccessful, it returns an
#* error message.
#*
#* @tag authentication
#* @serializer json list(na="string")
#*
#* @param user_name: The username provided by the user.
#* @param password: The password provided by the user.
#*
#* @response 200 OK. The JWT.
#* @response 401 Unauthorized. An error message indicating that the provided
#*             credentials were incorrect.
#* @response 404 Not Found. An error message indicating that the provided
#*             credentials were not valid.
#*
#* @get /api/auth/authenticate
function(req, res, user_name, password) {

  check_user <- user_name
  check_pass <- URLdecode(password)

  # load secret and convert to raw
  key <- charToRaw(dw$secret)

  # check if user provided credentials
      if (is.null(check_user) ||
        nchar(check_user) < 5 ||
        nchar(check_user) > 20 ||
        is.null(check_pass) ||
        nchar(check_pass) < 5 ||
        nchar(check_pass) > 50) {
      res$status <- 404
      res$body <- "Please provide valid username and password."
      res
      }

  # connect to database, find user in database and password is correct
  user_filtered <- pool %>%
    tbl("user") %>%
    filter(user_name == check_user & password == check_pass & approved == 1) %>%
    select(-password) %>%
    collect() %>%
    mutate(iat = as.numeric(Sys.time())) %>%
    mutate(exp = as.numeric(Sys.time()) + dw$refresh)

  # return answer depending on user credentials status
  if (nrow(user_filtered) != 1) {
    res$status <- 401
    res$body <- "User or password wrong."
    res
  }

  if (nrow(user_filtered) == 1) {
    claim <- jwt_claim(user_id = user_filtered$user_id,
    user_name = user_filtered$user_name,
    email = user_filtered$email,
    user_role = user_filtered$user_role,
    user_created = user_filtered$created_at,
    abbreviation = user_filtered$abbreviation,
    orcid = user_filtered$orcid,
    iat = user_filtered$iat,
    exp = user_filtered$exp)

    jwt <- jwt_encode_hmac(claim, secret = key)
    jwt
  }
}


#* Authenticate a User
#*
#* This endpoint is responsible for authenticating a user. It checks the
#* authorization header of the incoming request for a valid JSON Web Token (JWT).
#* If a valid JWT is provided and not expired, the endpoint returns the user's
#* information; otherwise, it returns an error.
#*
#* # `Details`
#* This is a Plumber endpoint function that uses JWT for user authentication.
#* JWT is a compact, URL-safe means of representing claims to be transferred
#* between two parties. The claims in a JWT are encoded as a JSON object that
#* is used as the payload of a JSON Web Signature (JWS) structure enabling the
#* claims to be digitally signed or integrity protected with a Message
#* Authentication Code (MAC) and/or encrypted.
#*
#* The function first checks if the 'Authorization' header is present in the
#* request. If not, it returns a 401 Unauthorized error. If the 'Authorization'
#* header is present, the function attempts to decode the JWT. If the JWT is
#* valid and not expired, the function returns the user's information. If the
#* JWT is not valid or expired, the function returns a 401 Unauthorized error.
#*
#* # `Return`
#* If successful, the function returns the user's information. If unsuccessful,
#* it returns an error message.
#*
#* @tag authentication
#* @serializer json list(na="string")
#*
#* @response 200 OK. The user's information.
#* @response 401 Unauthorized. An error message indicating that the 
#*             'Authorization' header was missing or that the provided JWT was
#*             not valid or expired.
#*
#* @get /api/auth/signin
function(req, res) {
  # load secret and convert to raw
  key <- charToRaw(dw$secret)

  if (is.null(req$HTTP_AUTHORIZATION)) {
    res$status <- 401 # Unauthorized
    return(list(error = "Authorization http header missing."))
  }

  # load jwt from header
  jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")

  tryCatch({
    user <- jwt_decode_hmac(jwt, secret = key)
    user$token_expired <- (user$exp < as.numeric(Sys.time()))
  }, error = function(e) {
    res$status <- 401 # Unauthorized
    return(list(error = "Authentication not successful."))
  })

  if (is.null(jwt) || user$token_expired) {
    res$status <- 401 # Unauthorized
    return(list(error = "Authentication not successful."))
  } else {
    return(list(user_id = user$user_id,
      user_name = user$user_name,
      email = user$email,
      user_role = user$user_role,
      user_created = user$user_created,
      abbreviation = user$abbreviation,
      orcid = user$orcid,
      exp = user$exp))
  }
}


#* Refresh the Authentication Token
#*
#* This endpoint is responsible for refreshing the user's authentication token.
#* It checks the authorization header of the incoming request for a valid
#* JSON Web Token (JWT). If a valid JWT is provided, the endpoint refreshes
#* the token; otherwise, it returns an error.
#*
#* # `Details`
#* This is a Plumber endpoint function that uses JWT for user authentication.
#* JWT is a compact, URL-safe means of representing claims to be transferred
#* between two parties. The claims in a JWT are encoded as a JSON object that
#* is used as the payload of a JSON Web Signature (JWS) structure enabling the
#* claims to be digitally signed or integrity protected with a Message
#* Authentication Code (MAC) and/or encrypted.
#*
#* The function first checks if the 'Authorization' header is present in the
#* request. If not, it returns a 401 Unauthorized error. If the 'Authorization'
#* header is present, the function attempts to decode the JWT. If the JWT is
#* valid and not expired, the function refreshes the token and returns the new
#* JWT. If the JWT is not valid or expired, the function returns a 401
#* Unauthorized error.
#*
#* # `Return`
#* If successful, the function returns the refreshed JWT. If unsuccessful, it
#* returns an error message.
#*
#* @tag authentication
#* @serializer json list(na="string")
#*
#* @response 200 OK. The refreshed JWT.
#* @response 401 Unauthorized. An error message indicating that the 
#*             'Authorization' header was missing or that the provided JWT was
#*             not valid or expired.
#*
#* @get /api/auth/refresh
function(req, res) {
  # load secret and convert to raw
  key <- charToRaw(dw$secret)

  if (is.null(req$HTTP_AUTHORIZATION)) {
    res$status <- 401 # Unauthorized
    return(list(error = "Authorization http header missing."))
  }

  # load jwt from header
  jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")

  tryCatch({
    user <- jwt_decode_hmac(jwt, secret = key)
    user$token_expired <- (user$exp < as.numeric(Sys.time()))
  }, error = function(e) {
    res$status <- 401 # Unauthorized
    return(list(error = "Authentication not successful."))
  })

  if (is.null(jwt) || user$token_expired) {
    res$status <- 401 # Unauthorized
    return(list(error = "Authentication not successful."))
  } else {
    claim <- jwt_claim(user_id = user$user_id,
      user_name = user$user_name,
      email = user$email,
      user_role = user$user_role,
      user_created = user$user_created,
      abbreviation = user$abbreviation,
      orcid = user$orcid,
      iat = as.numeric(Sys.time()),
      exp = as.numeric(Sys.time()) + dw$refresh)

    jwt <- jwt_encode_hmac(claim, secret = key)
    jwt
  }
}

##Authentication section
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Administration section

#* Updates ontology sets and identifies critical changes
#*
#* This endpoint performs an ontology update process by aggregating and updating
#* various ontology data sets. It is restricted to Administrator users and
#* handles the complex process of updating the ontology data, identifying
#* critical changes, and updating relevant database tables.
#*
#* # `Details`
#* The function starts by collecting data from multiple tables like 
#* mode_of_inheritance_list, non_alt_loci_set, and ndd_entity_view. It then computes
#* a new disease ontology set and identifies critical changes. Finally, it updates
#* the ndd_entity table with these changes and updates the database tables.
#*
#* # `Authorization`
#* Access to this endpoint is restricted to users with the 'Administrator' role. 
#* Any requests from users without this role will be denied.
#*
#* # `Return`
#* If successful, the function returns a success message. If the user is unauthorized,
#* it returns an error message indicating that access is forbidden.
#*
#* @tag admin
#* @serializer json list(na="string")
#* @put /api/admin/update_ontology
function(req) {
  # Check user role for Administrator access
  if (req$user_role != "Administrator") {
    res$status <- 403 # Forbidden
    return(list(error = "Access forbidden. Only administrators can perform this operation."))
  }

  # moi information from mode_of_inheritance_list table
  mode_of_inheritance_list <- pool %>%
    tbl("mode_of_inheritance_list") %>%
    select(-is_active, -sort) %>%
    collect()

  # gene information from non_alt_loci_set table
  non_alt_loci_set <- pool %>%
    tbl("non_alt_loci_set") %>%
    select(hgnc_id, symbol) %>%
    collect()

  # currently used ontology terms from ndd_entity_view
  ndd_entity_view <- pool %>%
      tbl("ndd_entity_view") %>%
    collect()

  ndd_entity_view_ontology_set <- ndd_entity_view %>%
      select(entity_id, disease_ontology_id_version,
            disease_ontology_name) %>%
    collect()

  # all current ontology terms from disease_ontology_set
  disease_ontology_set <- pool %>%
      tbl("disease_ontology_set") %>%
      select(disease_ontology_id_version,
      disease_ontology_id,
      hgnc_id,
      hpo_mode_of_inheritance_term,
      disease_ontology_name) %>%
    collect()

  # ndd_entity for later update
  ndd_entity <- pool %>%
      tbl("ndd_entity") %>%
    collect()

  # compute the new disease_ontology_set using the function process_combine_ontology
  disease_ontology_set_update <- process_combine_ontology(non_alt_loci_set, mode_of_inheritance_list, 3, "data/")

  # compute critical changes between old and new disease_ontology_set using the function identify_critical_ontology_changes
  critical_changes <- identify_critical_ontology_changes(
    disease_ontology_set_update,
    disease_ontology_set,
    ndd_entity_view_ontology_set
    )

  # mutate ndd_entity with critical changes
  # TODO: later this needs to be updated for the entities that can be automatically assigned
  ndd_entity_mutated <- ndd_entity %>%
      mutate(disease_ontology_id_version = case_when(
        (disease_ontology_id_version %in% critical_changes$disease_ontology_id_version) ~ "MONDO:0700096_1",
        TRUE ~ disease_ontology_id_version
      )) %>%
    mutate(entity_quadruple = paste0(hgnc_id, "-", disease_ontology_id_version, "-", hpo_mode_of_inheritance_term, "-", ndd_phenotype)) %>%
    mutate(number = 1) %>%
    group_by(entity_quadruple) %>%
    mutate(entity_quadruple_unique = n(),
    sum_number = cumsum(number)) %>%
    ungroup() %>%
      mutate(disease_ontology_id_version = case_when(
        entity_quadruple_unique > 1 & sum_number == 1 ~ "MONDO:0700096_1",
        entity_quadruple_unique > 1 & sum_number == 2 ~ "MONDO:0700096_2",
        entity_quadruple_unique > 1 & sum_number == 3 ~ "MONDO:0700096_3",
        entity_quadruple_unique > 1 & sum_number == 4 ~ "MONDO:0700096_4",
        entity_quadruple_unique > 1 & sum_number == 5 ~ "MONDO:0700096_5",
        TRUE ~ disease_ontology_id_version
      )) %>%
    select(-entity_quadruple, -number, - entity_quadruple_unique, -sum_number)

  # Connect to database
  sysndd_db <- dbConnect(RMariaDB::MariaDB(),
                         dbname = dw$dbname,
                         user = dw$user,
                         password = dw$password,
                         server = dw$server,
                         host = dw$host,
                         port = dw$port)

  # Start transaction
  dbBegin(sysndd_db)

  tryCatch({
    # Your existing code to process and update the ontology sets...
    # (process_combine_ontology, identify_critical_ontology_changes, etc.)

    # Database update operations...
    dbExecute(sysndd_db, "SET FOREIGN_KEY_CHECKS = 0;")
    dbExecute(sysndd_db, "TRUNCATE TABLE disease_ontology_set;")
    dbAppendTable(sysndd_db, "disease_ontology_set", disease_ontology_set_update)
    dbExecute(sysndd_db, "TRUNCATE TABLE ndd_entity;")
    dbAppendTable(sysndd_db, "ndd_entity", ndd_entity_mutated)
    dbExecute(sysndd_db, "SET FOREIGN_KEY_CHECKS = 1;")

    # Commit transaction
    dbCommit(sysndd_db)

    # Successful operation response
    return(list(status = "Success", message = "Ontology update process completed."))

  }, error = function(e) {
    # Rollback transaction in case of error
    dbRollback(sysndd_db)

    # Return error message
    res$status <- 500 # Internal Server Error
    return(list(error = "An error occurred during the update process. Transaction rolled back."))
  })

  # Close database connection
  dbDisconnect(sysndd_db)
}


#* Updates HGNC data and refreshes the non_alt_loci_set table in the MySQL database
#*
#* This endpoint performs an update process by downloading the latest HGNC data,
#* processing it, and updating the non_alt_loci_set table. It is restricted to Administrator users.
#*
#* # `Details`
#* The function starts by downloading the latest HGNC file, processing the gene information,
#* updating STRINGdb identifiers, computing gene coordinates, and then updating the
#* non_alt_loci_set table in the MySQL database with these new values.
#*
#* # `Authorization`
#* Access to this endpoint is restricted to users with the 'Administrator' role.
#* Any requests from users without this role will be denied.
#*
#* # `Return`
#* If successful, the function returns a success message. If the user is unauthorized,
#* it returns an error message indicating that access is forbidden.
#*
#* @tag admin
#* @serializer json list(na="string")
#* @put /api/admin/update_hgnc_data
function(req, res) {
  # Check user role for Administrator access
  if (req$user_role != "Administrator") {
    res$status <- 403 # Forbidden
    return(list(error = "Access forbidden. Only administrators can perform this operation."))
  }

  # Call the function to update the HGNC data
  hgnc_data <- update_process_hgnc_data()

  # Connect to database
  sysndd_db <- dbConnect(RMariaDB::MariaDB(),
                        dbname = dw$dbname,
                        user = dw$user,
                        password = dw$password,
                        server = dw$server,
                        host = dw$host,
                        port = dw$port)

  # Start transaction
  dbBegin(sysndd_db)

  # Ensure dbDisconnect is called even if an error occurs
  on.exit(dbDisconnect(sysndd_db), add = TRUE)

  tryCatch({

    # Update operations for the non_alt_loci_set table
    dbExecute(sysndd_db, "SET FOREIGN_KEY_CHECKS = 0;")
    dbExecute(sysndd_db, "TRUNCATE TABLE non_alt_loci_set;")
    dbWriteTable(sysndd_db, "non_alt_loci_set", hgnc_data, append = TRUE)
    dbExecute(sysndd_db, "SET FOREIGN_KEY_CHECKS = 1;")

    # Commit transaction
    dbCommit(sysndd_db)

    # Successful operation response
    list(status = "Success", message = "HGNC data update process completed.")

  }, error = function(e) {
    # Rollback transaction in case of error
    dbRollback(sysndd_db)

    # Return error message
    res$status <- 500 # Internal Server Error
    list(error = "An error occurred during the HGNC update process. Transaction rolled back.", details = e$message)
  })
}


#* Retrieves the current API version
#*
#* This endpoint provides the current version of the API. It's a simple utility
#* function that can be useful for clients to check the API version they are interacting with.
#* This can help in ensuring compatibility, especially when multiple versions of the API exist.
#*
#* # `Details`
#* The function utilizes the internal structure of the Plumber router (`pr`) to access the
#* API version. It's a read-only endpoint, primarily used for informational purposes.
#* The version number is retrieved programmatically from the Plumber router's environment.
#*
#* # `Authorization`
#* This endpoint does not require any specific user role for access. It is openly accessible
#* for any client or user who needs to know the API version.
#*
#* # `Return`
#* Returns a JSON object containing the current version of the API. The structure of the
#* return object is: `{"api_version": "x.y.z"}`, where `x.y.z` is the current version number.
#*
#* @tag admin
#* @serializer unboxedJSON list(na="string")
#* @get /api/admin/api_version
function() {
  version <- apiV()
  return(list(api_version = version))
}

## Administration section
##-------------------------------------------------------------------##