##-------------------------------------------------------------------##
# load libraries
library(plumber)
library(logger)
library(tictoc)
library(fs)
library(jsonlite)
library(DBI)
library(RMariaDB)
##-------------------------------------------------------------------##

##-------------------------------------------------------------------##
# set work directory
setwd("/sysndd_api_volume")
##-------------------------------------------------------------------##

##-------------------------------------------------------------------##
# Global API functions
# load source files
source("functions/config-functions.R", local = TRUE)
source("functions/logging-functions.R", local = TRUE)
##-------------------------------------------------------------------##

##-------------------------------------------------------------------##
# Load the API spec from the JSON file
api_spec <- fromJSON("config/api_spec.json", flatten = TRUE)
##-------------------------------------------------------------------##

##-------------------------------------------------------------------##
# Load config
dw <- config::get(Sys.getenv("API_CONFIG"))
##-------------------------------------------------------------------##

##-------------------------------------------------------------------##
# Specify how logs are written
log_dir <- "logs"
if (!fs::dir_exists(log_dir)) fs::dir_create(log_dir)
logging_temp_file <- tempfile("plumber_", log_dir, ".log")
log_appender(appender_file(logging_temp_file))
##-------------------------------------------------------------------##

##-------------------------------------------------------------------##
# start the API
root <- pr("sysndd_plumber.R") %>%
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

    # Write log entry to database
    log_message_to_db(
      address = convert_empty(req$REMOTE_ADDR),
      agent = convert_empty(req$HTTP_USER_AGENT),
      host = convert_empty(req$HTTP_HOST),
      request_method = convert_empty(req$REQUEST_METHOD),
      path = convert_empty(req$PATH_INFO),
      query = convert_empty(req$QUERY_STRING),
      post = convert_empty(req$postBody),
      status = convert_empty(res$status),
      duration = round(end$toc - end$tic, digits = getOption("digits", 5)),
      file = logging_temp_file,
      modified = Sys.time()
    )
  }) %>%
  pr_set_api_spec(function(spec) {
    spec$components$securitySchemes$bearerAuth$type <- "http"
    spec$components$securitySchemes$bearerAuth$scheme <- "bearer"
    spec$components$securitySchemes$bearerAuth$bearerFormat <- "JWT"
    spec$security[[1]]$bearerAuth <- ""

    # Set examples in OpenAPI spec
    spec <- update_api_spec_examples(spec, api_spec)

    # Return spec
    spec
  }) %>%
  pr_run(host = "0.0.0.0", port = 7777)
##-------------------------------------------------------------------##
