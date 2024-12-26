# sysndd_plumber.R
#
# Main Plumber script that sets up the SysNDD API, loads configuration,
# global variables, filters, and sources the separate endpoint scripts.

##-------------------------------------------------------------------##
# Load required libraries
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
# Load config
dw <- config::get(Sys.getenv("API_CONFIG"))

##-------------------------------------------------------------------##
# Global variables
# SMTP password if not set
if (nchar(Sys.getenv("SMTP_PASSWORD")) == 0) {
  Sys.setenv("SMTP_PASSWORD" = toString(dw$mail_noreply_password))
}

# Set time to GMT
Sys.setenv(TZ = "GMT")

##-------------------------------------------------------------------##
# Generate a pool of connections to the database
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
# Define common serializers, permitted values, etc.
serializers <- list(
  "json" = serializer_json(),
  "xlsx" = serializer_content_type(
    type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  )
)

inheritance_input_allowed <- c(
  "X-linked",
  "Autosomal dominant",
  "Autosomal recessive",
  "Other",
  "All"
)

output_columns_allowed <- c(
  "category",
  "inheritance",
  "symbol",
  "hgnc_id",
  "entrez_id",
  "ensembl_gene_id",
  "ucsc_id",
  "bed_hg19",
  "bed_hg38"
)

user_status_allowed <- c(
  "Administrator",
  "Curator",
  "Reviewer",
  "Viewer"
)

##-------------------------------------------------------------------##
# Plumber API global settings
options("plumber.apiURL" = dw$api_base_url)

# Load function scripts
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

# Convert some functions to memoised versions
cm <- cachem::cache_mem(
  max_age = 60 * 60,
  max_size = 100 * 1024^2
)

generate_stat_tibble_mem <- memoise(generate_stat_tibble, cache = cm)
generate_gene_news_tibble_mem <- memoise(generate_gene_news_tibble, cache = cm)
nest_gene_tibble_mem <- memoise(nest_gene_tibble, cache = cm)
generate_tibble_fspec_mem <- memoise(generate_tibble_fspec, cache = cm)
gen_string_clust_obj_mem <- memoise(gen_string_clust_obj, cache = cm)
gen_mca_clust_obj_mem <- memoise(gen_mca_clust_obj, cache = cm)
read_log_files_mem <- memoise(read_log_files, cache = cm)

# Function to get the API version
#' @plumber
function(pr) {
  assign("apiV",
         function() {
           pr$.__enclos_env__$private$globalSettings$info$version
         },
         envir = pr$environment)
}

##-------------------------------------------------------------------##
#* @apiTitle SysNDD API
#* @apiDescription This is the API powering the SysNDD website
#* and allowing programmatic access to the database contents.
#* @apiVersion 0.1.0
#* @apiTOS https://sysndd.dbmr.unibe.ch/About
#* @apiContact list(name = "API Support",
#*                  url = "https://berntpopp.github.io/sysndd/api.html",
#*                  email = "support@sysndd.org")
#* @apiLicense list(name = "CC BY 4.0",
#*                  url = "https://creativecommons.org/licenses/by/4.0/")
#*
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
## Hooks
#* @plumber
function(pr) {
  pr %>%
    plumber::pr_hook("exit", function() {
      pool::poolClose(pool)
      message("Disconnected")
    })
}

##-------------------------------------------------------------------##
## Filters

#* @filter cors
#* enables cross-origin requests
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  if (req$REQUEST_METHOD == "OPTIONS") {
    res$setHeader("Access-Control-Allow-Methods", "*")
    res$setHeader(
      "Access-Control-Allow-Headers",
      req$HTTP_ACCESS_CONTROL_REQUEST_HEADERS
    )
    res$status <- 200
    return(list())
  } else {
    plumber::forward()
  }
}

#* @filter check_signin
#* checks signin from header token and sets user variables on request
function(req, res) {
  key <- charToRaw(dw$secret)

  if (req$REQUEST_METHOD == "GET" && is.null(req$HTTP_AUTHORIZATION)) {
    plumber::forward()
  } else if (req$REQUEST_METHOD == "GET" && !is.null(req$HTTP_AUTHORIZATION)) {
    jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")
    tryCatch({
      user <- jwt_decode_hmac(jwt, secret = key)
    }, error = function(e) {
      res$status <- 401
      return(list(error = "Token expired or invalid."))
    })
    req$user_id <- as.integer(user$user_id)
    req$user_role <- user$user_role
    plumber::forward()
  } else if (
    req$REQUEST_METHOD == "POST" &&
    (req$PATH_INFO == "/api/gene/hash" || req$PATH_INFO == "/api/entity/hash")
  ) {
    plumber::forward()
  } else {
    if (is.null(req$HTTP_AUTHORIZATION)) {
      res$status <- 401
      return(list(error = "Authorization http header missing."))
    } else {
      decoded_jwt <- jwt_decode_hmac(
        str_remove(req$HTTP_AUTHORIZATION, "Bearer "),
        secret = key
      )
      if (decoded_jwt$exp < as.numeric(Sys.time())) {
        res$status <- 401
        return(list(error = "Token expired."))
      } else {
        req$user_id <- as.integer(decoded_jwt$user_id)
        req$user_role <- decoded_jwt$user_role
        plumber::forward()
      }
    }
  }
}
