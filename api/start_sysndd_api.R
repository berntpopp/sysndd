######################################################################
# start_sysndd_api.R
#
# A single script that:
#  - Loads all required libraries and config
#  - Loads environment variables from .env via dotenv
#  - Decides environment (local/production) via ENVIRONMENT variable
#  - Uses config.yml to get 'workdir' (and everything else)
#  - Creates & memoizes global objects (pool, serializers, etc.)
#  - Defines Plumber filters & hooks
#  - Mounts endpoint scripts at /api/<something>
#  - Runs the API
#
# Run it with: Rscript start_sysndd_api.R
# Or set ENVIRONMENT=production to run with production config.
######################################################################

##-------------------------------------------------------------------##
# 1) Load Required Libraries
##-------------------------------------------------------------------##
library(dotenv)
dotenv::load_dot_env(file = ".env")  # This reads variables from .env if present

library(plumber)
library(logger)
library(tictoc)
library(fs)
library(jsonlite)
library(DBI)
library(RMariaDB)
library(config)
library(pool)

# Additional libraries from your old sysndd_plumber.R
library(biomaRt)
library(tidyverse)
library(stringr)
library(jose)
library(RCurl)
library(stringdist)
library(xlsx)
library(easyPubMed)
library(xml2)
library(rvest)
library(lubridate)
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
# set redirect to trailing slash
options_plumber(trailingSlash = TRUE)
##-------------------------------------------------------------------##

##-------------------------------------------------------------------##
# 2) Decide which environment (local vs production)
##-------------------------------------------------------------------##
env_mode <- Sys.getenv("ENVIRONMENT", "local")
# If ENVIRONMENT is not set (or missing in .env), default to "local"

message(paste("ENVIRONMENT set to:", env_mode))

# Map that environment to the config key:
if (tolower(env_mode) == "production") {
  Sys.setenv(API_CONFIG = "sysndd_db")  # Production entry in config.yml
} else {
  Sys.setenv(API_CONFIG = "sysndd_db_local")  # Local entry in config.yml
}

##-------------------------------------------------------------------##
# 3) Read config and set working directory from config
##-------------------------------------------------------------------##
dw <- config::get(Sys.getenv("API_CONFIG"))
# Above line reads from config.yml the environment block
# e.g. sysndd_db_local or sysndd_db

# If you have a field 'workdir' in the config, do:
if (!is.null(dw$workdir)) {
  message(paste("Setting working directory to:", dw$workdir))
  setwd(dw$workdir)
} else {
  message("No 'workdir' specified in config. Using current working directory.")
}

##-------------------------------------------------------------------##
# 4) Load Additional Scripts (Helper Functions)
##-------------------------------------------------------------------##
source("functions/config-functions.R",         local = TRUE)
source("functions/logging-functions.R",        local = TRUE)
source("functions/database-functions.R",       local = TRUE)
source("functions/endpoint-functions.R",       local = TRUE)
source("functions/publication-functions.R",    local = TRUE)
source("functions/genereviews-functions.R",    local = TRUE)
source("functions/analyses-functions.R",       local = TRUE)
source("functions/helper-functions.R",         local = TRUE)
source("functions/external-functions.R",       local = TRUE)
source("functions/file-functions.R",           local = TRUE)
source("functions/hpo-functions.R",            local = TRUE)
source("functions/hgnc-functions.R",           local = TRUE)
source("functions/ontology-functions.R",       local = TRUE)
source("functions/pubtator-functions.R",       local = TRUE)
source("functions/ensembl-functions.R",        local = TRUE)

##-------------------------------------------------------------------##
# 5) Load the API spec for OpenAPI (optional)
##-------------------------------------------------------------------##
api_spec <- fromJSON("config/api_spec.json", flatten = TRUE)

##-------------------------------------------------------------------##
# 6) Setup logging
##-------------------------------------------------------------------##
log_dir <- "logs"
if (!dir_exists(log_dir)) fs::dir_create(log_dir)
logging_temp_file <- tempfile("plumber_", log_dir, ".log")
log_appender(appender_file(logging_temp_file))

##-------------------------------------------------------------------##
# 7) Create a global DB pool in the global environment
##-------------------------------------------------------------------##
pool <<- dbPool(
  drv      = RMariaDB::MariaDB(),
  dbname   = dw$dbname,
  host     = dw$host,
  user     = dw$user,
  password = dw$password,
  server   = dw$server,
  port     = dw$port
)

##-------------------------------------------------------------------##
# 8) Define global objects (serializers, allowed arrays, etc.)
##-------------------------------------------------------------------##
serializers <<- list(
  "json" = serializer_json(),
  "xlsx" = serializer_content_type(
    type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  )
)

inheritance_input_allowed <<- c(
  "X-linked",
  "Autosomal dominant",
  "Autosomal recessive",
  "Other",
  "All"
)

output_columns_allowed <<- c(
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

user_status_allowed <<- c("Administrator", "Curator", "Reviewer", "Viewer")

# Load version info from version_spec.json
version_json <<- fromJSON("version_spec.json")
sysndd_api_version <<- version_json$version

##-------------------------------------------------------------------##
# 9) Memoize certain functions
##-------------------------------------------------------------------##
cm <- cachem::cache_mem(
  max_age  = 60 * 60,         # 1 hour
  max_size = 100 * 1024^2     # 100 MB
)

generate_stat_tibble_mem       <<- memoise(generate_stat_tibble,       cache = cm)
generate_gene_news_tibble_mem  <<- memoise(generate_gene_news_tibble,  cache = cm)
nest_gene_tibble_mem           <<- memoise(nest_gene_tibble,           cache = cm)
generate_tibble_fspec_mem      <<- memoise(generate_tibble_fspec,      cache = cm)
gen_string_clust_obj_mem       <<- memoise(gen_string_clust_obj,       cache = cm)
gen_mca_clust_obj_mem          <<- memoise(gen_mca_clust_obj,          cache = cm)
read_log_files_mem             <<- memoise(read_log_files,             cache = cm)
nest_pubtator_gene_tibble_mem             <<- memoise(nest_pubtator_gene_tibble,             cache = cm)

##-------------------------------------------------------------------##
# 10) Define filters as named functions with roxygen tags
##-------------------------------------------------------------------##
#* @filter cors
corsFilter <- function(req, res) {
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
checkSignInFilter <- function(req, res) {
  key <- charToRaw(dw$secret)

  # GET without auth => forward
  if (req$REQUEST_METHOD == "GET" && is.null(req$HTTP_AUTHORIZATION)) {
    plumber::forward()
  }
  # GET with Bearer token => decode
  else if (req$REQUEST_METHOD == "GET" && !is.null(req$HTTP_AUTHORIZATION)) {
    jwt <- str_remove(req$HTTP_AUTHORIZATION, "Bearer ")
    tryCatch({
      user <- jwt_decode_hmac(jwt, secret = key)
    }, error = function(e) {
      res$status <- 401
      return(list(error = "Token expired or invalid."))
    })
    req$user_id  <- as.integer(user$user_id)
    req$user_role<- user$user_role
    plumber::forward()
  }
  # POST to /api/entity/hash or /api/gene/hash => forward
  else if (
    req$REQUEST_METHOD == "POST" &&
    (req$PATH_INFO == "/api/gene/hash" || req$PATH_INFO == "/api/entity/hash")
  ) {
    plumber::forward()
  }
  # PUT to /api/user/password/reset/request
  else if (
    req$REQUEST_METHOD == "PUT" &&
    (req$PATH_INFO == "/api/user/password/reset/request")
  ) {
    plumber::forward()
  }
  # Otherwise require Bearer token
  else {
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
        req$user_id  <- as.integer(decoded_jwt$user_id)
        req$user_role<- decoded_jwt$user_role
        plumber::forward()
      }
    }
  }
}

##-------------------------------------------------------------------##
# 11) We define a named function for the final 'exit' hook
##-------------------------------------------------------------------##
#* @plumber
cleanupHook <- function(pr) {
  pr %>%
    pr_hook("exit", function() {
      pool::poolClose(pool)
      message("Disconnected from DB")
    })
}

##-------------------------------------------------------------------##
# 12) Create root plumber router with doc lines for the entire API
##-------------------------------------------------------------------##
root <- pr() %>%
  
  # Insert doc info in pr_set_api_spec
  pr_set_api_spec(function(spec) {
    # -----------------------------------------------------------------
    #  We read from version_spec.json for the version info:
    # -----------------------------------------------------------------
    version_info <- fromJSON("version_spec.json")  # Load your JSON file
    # Set the spec fields from version_info:
    spec$info$title       <- version_info$title
    spec$info$description <- version_info$description
    spec$info$version     <- version_info$version

    if (!is.null(version_info$contact)) {
      spec$info$contact <- version_info$contact
    }
    if (!is.null(version_info$license)) {
      spec$info$license <- version_info$license
    }
    
    spec$components$securitySchemes$bearerAuth$type         <- "http"
    spec$components$securitySchemes$bearerAuth$scheme       <- "bearer"
    spec$components$securitySchemes$bearerAuth$bearerFormat <- "JWT"
    spec$security[[1]]$bearerAuth                           <- ""
    
    # Insert example requests from your api_spec.json (optional)
    spec <- update_api_spec_examples(spec, api_spec)
    spec
  }) %>%
  
  ####################################################################
  # Attach filters
  ####################################################################
  pr_filter("cors", corsFilter) %>%
  pr_filter("check_signin", checkSignInFilter) %>%
  
  ####################################################################
  # Attach exit hook
  ####################################################################
  cleanupHook() %>%
  
  ####################################################################
  # Mount each endpoint file at /api/<subpath>
  ####################################################################
  pr_mount("/api/entity",         pr("endpoints/entity_endpoints.R")) %>%
  pr_mount("/api/review",         pr("endpoints/review_endpoints.R")) %>%
  pr_mount("/api/re_review",      pr("endpoints/re_review_endpoints.R")) %>%
  pr_mount("/api/publication",    pr("endpoints/publication_endpoints.R")) %>%
  pr_mount("/api/gene",           pr("endpoints/gene_endpoints.R")) %>%
  pr_mount("/api/ontology",       pr("endpoints/ontology_endpoints.R")) %>%
  pr_mount("/api/phenotype",      pr("endpoints/phenotype_endpoints.R")) %>%
  pr_mount("/api/status",         pr("endpoints/status_endpoints.R")) %>%
  pr_mount("/api/panels",         pr("endpoints/panels_endpoints.R")) %>%
  pr_mount("/api/comparisons",    pr("endpoints/comparisons_endpoints.R")) %>%
  pr_mount("/api/analysis",       pr("endpoints/analysis_endpoints.R")) %>%
  pr_mount("/api/hash",           pr("endpoints/hash_endpoints.R")) %>%
  pr_mount("/api/search",         pr("endpoints/search_endpoints.R")) %>%
  pr_mount("/api/list",           pr("endpoints/list_endpoints.R")) %>%
  pr_mount("/api/logs",           pr("endpoints/logging_endpoints.R")) %>%
  pr_mount("/api/user",           pr("endpoints/user_endpoints.R")) %>%
  pr_mount("/api/auth",           pr("endpoints/authentication_endpoints.R")) %>%
  pr_mount("/api/admin",          pr("endpoints/admin_endpoints.R")) %>%
  pr_mount("/api/external",       pr("endpoints/external_endpoints.R")) %>%
  pr_mount("/api/statistics",     pr("endpoints/statistics_endpoints.R")) %>%
  pr_mount("/api/variant",        pr("endpoints/variant_endpoints.R")) %>%
  # -------------------------------------------------------------------

  ####################################################################
  # preroute / postroute hooks for timing & logging
  ####################################################################
  pr_hook("preroute", function() {
    tictoc::tic()
  }) %>%
  pr_hook("postroute", function(req, res) {
    end <- tictoc::toc(quiet = TRUE)
    
    log_entry <- paste(
      convert_empty(req$REMOTE_ADDR),
      convert_empty(req$HTTP_USER_AGENT),
      convert_empty(req$HTTP_HOST),
      convert_empty(req$REQUEST_METHOD),
      convert_empty(req$PATH_INFO),
      convert_empty(req$QUERY_STRING),
      convert_empty(req$postBody),
      convert_empty(res$status),
      round(end$toc - end$tic, digits = getOption("digits", 5)),
      sep = ";",
      collapse = ""
    )
    log_info(skip_formatter(log_entry))
    
    # Write log entry to DB
    log_message_to_db(
      address         = convert_empty(req$REMOTE_ADDR),
      agent           = convert_empty(req$HTTP_USER_AGENT),
      host            = convert_empty(req$HTTP_HOST),
      request_method  = convert_empty(req$REQUEST_METHOD),
      path            = convert_empty(req$PATH_INFO),
      query           = convert_empty(req$QUERY_STRING),
      post            = convert_empty(req$postBody),
      status          = convert_empty(res$status),
      duration        = round(end$toc - end$tic, digits = getOption("digits", 5)),
      file            = logging_temp_file,
      modified        = Sys.time()
    )
  })

##-------------------------------------------------------------------##
# 13) Finally, run the API
##-------------------------------------------------------------------##
# For example, you could do port = as.numeric(dw$port_self) if that’s in your config
root %>% pr_run(host = "0.0.0.0", port = as.numeric(dw$port_self))
