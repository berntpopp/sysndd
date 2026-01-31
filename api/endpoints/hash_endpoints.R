# api/endpoints/hash_endpoints.R
#
# This file contains all hash-related endpoints, extracted from the original
# sysndd_plumber.R. It follows the Google R Style Guide conventions where
# possible (e.g., two-space indentation, meaningful function names, etc.).

## -------------------------------------------------------------------##
## Hash endpoints
## -------------------------------------------------------------------##

#* Create a Hash for a List of Identifiers
#*
#* This endpoint takes a list of identifiers, sorts and hashes them,
#* then saves and returns a hash link.
#*
#* # `Details`
#* Creates a hash link for a list of identifiers. Uses the helper
#* post_db_hash() to store the list in the database, associating it
#* with a unique hash.
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
#* @post create
function(req, res, endpoint = "/api/gene") {
  json_data <- req$argsBody$json_data

  if (is.null(json_data)) {
    res$status <- 400
    res$body <- jsonlite::toJSON(
      auto_unbox = TRUE,
      list(
        status = 400,
        message = paste0(
          "Required 'json_data' parameter not provided."
        )
      )
    )
    return(res)
  } else {
    response_hash <- post_db_hash(
      json_data,
      "symbol,hgnc_id,entity_id",
      endpoint
    )
    return(response_hash)
  }
}

## Hash endpoints
## -------------------------------------------------------------------##
