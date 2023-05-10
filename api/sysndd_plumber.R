# sysndd_plumber.R


##-------------------------------------------------------------------##
# load libraries
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
inheritance_input_allowed <- c("X-linked",
  "Autosomal dominant",
  "Autosomal recessive",
  "Other",
  "All")

# TODO: This needs to go into the database as helper
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
source("functions/analyses-functions.R", local = TRUE)
source("functions/helper-functions.R", local = TRUE)
source("functions/external-functions.R", local = TRUE)

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
#* @apiTag user User account related endpoints
#* @apiTag authentication Authentication related endpoints
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
    user <- jwt_decode_hmac(str_remove(req$HTTP_AUTHORIZATION, "Bearer "),
      secret = key)
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
function(res,
  sort = "entity_id",
  filter = "",
  fields = "",
  `page_after` = 0,
  `page_size` = "10",
  fspec = "entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details") {

  start_time <- Sys.time()

  # generate sort expression based on sort input
  sort_exprs <- generate_sort_expressions(sort, unique_id = "entity_id")

  # generate filter expression based on filter input
  filter_exprs <- generate_filter_expressions(filter)

  # get review data from database
  ndd_entity_review <- pool %>%
    tbl("ndd_entity_review") %>%
    filter(is_primary) %>%
    select(entity_id, synopsis)

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
      pivot_wider(everything(), names_from = "type", values_from = "link")

  # generate object to return
  list(links = links,
    meta = meta,
    data = disease_table_pagination_info$data)
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
          select(-gr_check)

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
          select(entity_id = `response_entity$entry$entity_id`,
            synopsis = value,
            review_user_id,
            comment = `create_data$review$comment`)
      } else {
        sysnopsis_received <- tibble::as_tibble(create_data$review$synopsis) %>%
          add_column(response_entity$entry$entity_id) %>%
          add_column(review_user_id) %>%
          select(entity_id = `response_entity$entry$entity_id`,
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
        select(status, message) %>%
        mutate(status = max(status)) %>%
        mutate(message = str_c(message, collapse = "; ")) %>%
        unique()
      ##-------------------------------------------------------------------##
    ##-------------------------------------------------------------------##
    } else {
      res$status <- response_entity$status
      return(list(status = response_entity$status,
        message = response_entity$message))
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

#* @tag review
#* gets review list
#* @serializer json list(na="null")
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


#* @tag review
#* posts or puts a new clinical synopsis for a entity_id
#* @serializer json list(na="string")
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


#* @tag review
#* gets a single review by review_id
#* @serializer json list(na="null")
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


#* @tag review
#* gets all phenotypes for a review
#* @serializer json list(na="string")
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


#* @tag review
#* gets all variant_ontology terms for a review
#* @serializer json list(na="string")
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


#* @tag review
#* gets all publications for a reviews_id
#* @serializer json list(na="string")
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


#* @tag review
#* puts the review approvement (only Administrator and Curator status users)
#* @serializer json list(na="string")
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

#* @tag re_review
#* puts the re-review submission
#* @serializer json list(na="string")
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


#* @tag re_review
#* puts a re-review submission back into un-submitted mode
#* (only Administrator and Curator status users)
#* @serializer json list(na="string")
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


#* @tag re_review
#* puts the re-review status and review approvement
#* (only Administrator and Curator status users)
#* @serializer json list(na="string")
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


#* @tag re_review
#* gets the re-review overview table for the user logged in
#* @serializer json list(na="string")
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


#* @tag re_review
#* requests a new batch of entities to review by mail to curators
#* @serializer json list(na="string")
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


#* @tag re_review
#* puts a new re-review batch assignment
#* @serializer json list(na="string")
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


#* @tag re_review
#* deletes certain re-review batch assignment
#* @serializer json list(na="string")
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


#* @tag re_review
#* gets a summary table of currently assigned re-review batches
#* @serializer json list(na="string")
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

#* @tag publication
#* gets a publication by pmid
#* @serializer json list(na="string")
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


#* @tag publication
#* validates if a pmid exists in pubmed
#* @serializer json list(na="string")
#* @get /api/publication/validate/<pmid>
function(req, res, pmid) {

  pmid <- URLdecode(pmid) %>%
    str_replace_all("[^0-9]+", "")

  check_pmid(pmid)
}

## Publication endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Gene endpoints

#* @tag gene
#* allows filtering and field selection from all genes and associated entities
#* @serializer json list(na="string")
#* @param sort:str  Output column to arrange output on.
#* @param filter:str Comma separated list of filters to apply.
#* @param fields:str Comma separated list of output columns.
#* @param page_after:str Cursor after which to show entries in cursor pagination.
#* @param page_size:str Page size in cursor pagination.
#* @param fspec:str Fields for which to generate the fied specification in the meta data response.
#* @get /api/gene
function(res,
  sort = "symbol",
  filter = "",
  fields = "",
  `page_after` = "0",
  `page_size` = "10",
  fspec = "symbol,category,hpo_mode_of_inheritance_term_name,ndd_phenotype_word,entities_count,details") {

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
      pivot_wider(everything(), names_from = "type", values_from = "link")

  # generate object to return
  list(links = links,
    meta = meta,
    data = genes_nested_pag_info$data)
}


#* @tag gene
#* gets infos for a single gene by hgnc_id
#* @serializer json list(na="null")
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

#* @tag ontology
#* gets an ontology entry by disease_ontology_id_version
#* @serializer json list(na="null")
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
#* This endpoint returns a list of entities associated with a list of phenotypes
#* based on the data in the database.
#* 
#* @tag phenotype
#* @serializer json list(na="string")
#* @param sort:str Output column to arrange output on.
#* @param filter:str Comma separated list of filters to apply.
#* @param fields:str Comma separated list of output columns.
#* @param page_after:str Cursor after which to show entries in cursor
#* pagination.
#* @param page_size:str Page size in cursor pagination.
#* @param fspec:str Fields for which to generate the field specification in
#* the meta data response.
#* @param format:str The output format, either "json" or "xlsx". Defaults to
#* "json".
#* @return A data frame containing the list of entities associated with the
#* list of phenotypes.
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
#* @tag phenotype
#* @serializer json list(na="string")
#* @param res The res parameter that is not used in this function,
#* but is required by the plumber package.
#* @param filter:str A string representing a filter query to use when selecting
#* data from the database. By default, the filter is set to
#* "contains(ndd_phenotype_word,Yes),any(category,Definitive)". This parameter
#* is optional.
#* @return A data frame containing the correlation matrix between phenotypes,
#* with the columns "x", "x_id", "y", "y_id", and "value". The "x" and "y"
#* columns represent the names of the phenotypes, the "x_id" and "y_id" columns
#* represent the corresponding HPO IDs, and the "value" column represents the
#* correlation coefficient between the two phenotypes.
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
#* @tag phenotype
#* @serializer json list(na="string")
#* @param res A parameter that is not used in this function, but is required
#* by the plumber package.
#* @param filter:str A string representing a filter query to use when selecting
#* data from the database. By default, the filter is set to
#* "contains(ndd_phenotype_word,Yes),any(category,Definitive)". This parameter
#* is optional.
#* @return A data frame containing the counts of phenotypes in annotated
#* entities, with the columns "HPO_term", "phenotype_id", and "count". The
#* "HPO_term" column represents the name of the phenotype, the "phenotype_id"
#* column represents the corresponding HPO ID, and the "count" column represents
#* the number of times the phenotype appears in annotated entities.
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

#* @tag status
#* gets the status list
#* @serializer json list(na="null")
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


#* @tag status
#* gets a single status by status_id
#* @serializer json list(na="null")
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

#* @tag status
#* gets a list of all status
#* @serializer json list(na="string")
#* @get /api/status_list
function() {
  status_list_collected <- pool %>%
    tbl("ndd_entity_status_categories_list") %>%
    arrange(category_id) %>%
    collect()
}


#* @tag status
#* posts a new status for a entity_id or put an update to a certain status_id
## example data: '{"status_id":3,"entity_id":3,"category_id":1,"comment":"fsa","problematic": true}'
## (provide status_id for put and entity_id for post requests)
#* @serializer json list(na="string")
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


#* @tag status
#* puts the status approvement
#* (only Administrator and Curator status users)
#* @serializer json list(na="string")
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

#* @tag panels
#* gets list of all panel filtering options
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


#* @tag panels
#* gets panel data by category and inheritance terms
#* @serializer json list(na="string")
#* @param sort Output column to arrange output on.
#* @param filter Comma separated list of filters to apply.
#* @param fields Comma separated list of output columns.
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

#* @tag statistics
#* gets statistics for all genes associated with a
#* NDD phenotype by inheritance and association category
#* @serializer json list(na="string")
#* @get /api/statistics/category_count
function(sort = "category_id,-n",
  type = "gene") {
 disease_genes_statistics <- generate_stat_tibble_mem(sort, type)

 disease_genes_statistics
}


#* @tag statistics
#* gets last n entries in definitive category as news
#* @serializer json list(na="string")
#* @get /api/statistics/news
function(n = 5) {
 sysndd_db_disease_genes_news <- generate_gene_news_tibble_mem(n)

 sysndd_db_disease_genes_news
}


#* @tag statistics
#* gets database entry development over time
#* @serializer json list(na="string")
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
    nest_by(!!rlang::sym(group), .key = "values") %>%
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

#* @tag comparisons
#* gets list of all panel filtering options
#* @serializer json list(na="string")
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


#* @tag comparisons
#* return plot data showing intersection between different databases
#* @serializer json list(na="string")
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


#* @tag comparisons
#* gets cosine similarity data between different databases for plotting
#* @serializer json list(na="string")
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


#* @tag comparisons
#* returns a table showing the presence of
#* NDD associated genes in different databases
#* @serializer json list(na="string")
#* @param sort:str  Output column to arrange output on.
#* @param filter:str Comma separated list of filters to apply.
#* @param fields:str Comma separated list of output columns.
#* @param page_after:str Cursor after which to show entries in cursor pagination.
#* @param page_size:str Page size in cursor pagination.
#* @param fspec:str Fields for which to generate the fied specification in the meta data response.
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
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Analyses endpoints

#* @tag analysis
#* gene clusters using stringdb
#* @serializer json list(na="string")
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

#* @tag analysis
#* entity clusters from phenotypes using MCA and HC
#* @serializer json list(na="string")
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
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Hash endpoints
#* @tag hash
#* takes a list of identifiers, sorts, hashes and safes this, then returns the hash link
#* @serializer json list(na="string")
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
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Search endpoints

#* @tag search
#* searches the entity view by columns entity_id,
#* hgnc_id, symbol, disease_ontology_id_version, disease_ontology_name
#* @serializer json list(na="string")
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
    mutate(link = case_when(
      search == "hgnc_id" ~ paste0("/Genes/", results),
      search == "symbol" ~ paste0("/Genes/", results),
      search == "disease_ontology_id_version" ~ paste0("/Ontology/", results),
      search == "disease_ontology_name" ~ paste0("/Ontology/", results),
      search == "entity_id" ~ paste0("/Entities/", results)
    ))

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
      nest_by(results, .key = "values") %>%
      ungroup() %>%
      pivot_wider(everything(), names_from = "results", values_from = "values")
  } else {
    sysndd_db_entity_search_return
  }

  # return output
  sysndd_db_entity_search_return
}


#* @tag search
#* searches the search_disease_ontology_set view by
#* columns disease_ontology_id_version, disease_ontology_name
#* @serializer json list(na="string")
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
      nest_by(result, .key = "values") %>%
      ungroup() %>%
      pivot_wider(everything(), names_from = "result", values_from = "values")
  }

  # return output
  do_set_search_return_helper
}


#* @tag search
#* searches the search_non_alt_loci_view table by columns hgnc_id, symbol
#* @serializer json list(na="string")
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
      nest_by(result, .key = "values") %>%
      ungroup() %>%
      pivot_wider(everything(), names_from = "result", values_from = "values")
  }

  # return output
  nal_set_search_return_helper
}


#* @tag search
#* searches the search_mode_of_inheritance_list_view table by columns
#* hpo_mode_of_inheritance_term_name, hpo_mode_of_inheritance_term
#* @serializer json list(na="string")
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
      nest_by(result, .key = "values") %>%
      ungroup() %>%
      pivot_wider(everything(), names_from = "result", values_from = "values")
  }

  # return output
  moi_list_search_return_helper
}

## Search endpoints
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## List endpoints

#* @tag list
#* gets a list of all status
#* @serializer json list(na="string")
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
      nest_by(category, .key = "values") %>%
      ungroup() %>%
      pivot_wider(everything(), names_from = "category", values_from = "values")
  }

  # return output
  status_list_return_helper
}


#* @tag list
#* gets a list of all phenotypes
#* @serializer json list(na="string")
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


#* @tag list
#* gets a list of all inheritance terms
#* @serializer json list(na="string")
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
      select(id = hpo_mode_of_inheritance_term, label = hpo_mode_of_inheritance_term_name)
  } else {
    moi_list_return_helper <- moi_list_collected %>%
      nest_by(hpo_mode_of_inheritance_term, .key = "values") %>%
      ungroup() %>%
      pivot_wider(everything(), names_from = "hpo_mode_of_inheritance_term", values_from = "values")
  }

  # return output
  moi_list_return_helper
}


#* @tag list
#* gets a list of all variation ontology terms
#* @serializer json list(na="string")
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
#* @tag external
#* takes a sysndd URl and submits it to archive.org
#* @serializer json list(na="string")
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
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## User endpoint section

#* @tag user
#* gets a summary table of users
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


#* @tag user
#* gets count statistics of all contributions of a user
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


#* @tag user
#* manages user application approval
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
      res <- send_noreply_email(c(
         "Your registration for sysndd.org has been approved by a curator.",
         "Your password (please change after first login):",
         user_password),
         "Account approved for SysNDD.org",
         user_table$email
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


#* @tag user
#* manages user application approval
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


#* @tag user
#* gets a list of all available user status options
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


#* @tag user
#* gets a list of users based having a role
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


#* @tag user
#* changes the user password
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


#* @tag user
#* request password reset
#* @get /api/user/password/reset/request
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

## User endpoint section
##-------------------------------------------------------------------##



##-------------------------------------------------------------------##
## Authentication section

#* @tag authentication
#* manages user signup
#* @serializer json list(na="string")
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
    res <- send_noreply_email(c(
       "Your registration request for sysndd.org has been send to the curators",
       "who will review it soon. Information provided:",
       user),
       "Your registration request to SysNDD.org",
       user$email
      )

  } else {
    res$status <- 404
    res$body <- "Please provide valid registration data."
    res
  }
}


#* @tag authentication
#* does user login
## based on "https://github.com/
## jandix/sealr/blob/master/examples/jwt_simple_example.R"
#* @serializer json list(na="string")
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


#* @tag authentication
#* does user authentication
#* @serializer json list(na="string")
#* @get /api/auth/signin
function(req, res) {
  # load secret and convert to raw
  key <- charToRaw(dw$secret)

  # load jwt from header
  jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")

  user <- jwt_decode_hmac(jwt, secret = key)
  user$token_expired <- (user$exp < as.numeric(Sys.time()))

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


#* @tag authentication
#* does authentication refresh
#* @serializer json list(na="string")
#* @get /api/auth/refresh
function(req, res) {
  # load secret and convert to raw
  key <- charToRaw(dw$secret)

  # load jwt from header
  jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")

  user <- jwt_decode_hmac(jwt, secret = key)
  user$token_expired <- (user$exp < as.numeric(Sys.time()))

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
