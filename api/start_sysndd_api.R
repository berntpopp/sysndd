##-------------------------------------------------------------------##
# load libraries
library(plumber)
library(logger)
library(tictoc)
library(fs)
library(jsonlite) # for api spec examples
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
# Specify how logs are written
log_dir <- "logs"
if (!fs::dir_exists(log_dir)) fs::dir_create(log_dir)
log_appender(appender_file(tempfile("plumber_", log_dir, ".log")))
##-------------------------------------------------------------------##


##-------------------------------------------------------------------##
# start the API
root <- pr("sysndd_plumber.R") %>%
    pr_hook("preroute", function() {
      tictoc::tic()
    }) %>%
    pr_hook("postroute", function(req, res) {
            end <- tictoc::toc(quiet = TRUE)
             # Log details about the request and the response
            log_info(paste("{convert_empty(req$REMOTE_ADDR)}",
            "'{convert_empty(req$HTTP_USER_AGENT)}'",
            "{convert_empty(req$HTTP_HOST)}",
            "{convert_empty(req$REQUEST_METHOD)}",
            "{convert_empty(req$PATH_INFO)}",
            "{convert_empty(req$QUERY_STRING)}",
            "{convert_empty(req$postBody)}",
            "{convert_empty(res$status)}",
            "{round(end$toc - end$tic, digits = getOption('digits', 5))}",
            sep = ";",
            collapse = "")
            )
        }) %>%
    pr_set_api_spec(function(spec) {
      spec$components$securitySchemes$bearerAuth$type <- "http"
      spec$components$securitySchemes$bearerAuth$scheme <- "bearer"
      spec$components$securitySchemes$bearerAuth$bearerFormat <- "JWT"
      spec$security[[1]]$bearerAuth <- ""

      ##-------------------------------------------------------------------##
      # set examples in OpenAPI spec
      spec <- update_api_spec_examples(spec, api_spec)
      ##-------------------------------------------------------------------##

      ## return spec
      spec
    }) %>%
        pr_run(host = "0.0.0.0", port = 7777)
