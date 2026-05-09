# api/endpoints/seo_endpoints.R
#
# Public compact payloads for frontend-owned SEO prerendering.

set_seo_cache_headers <- function(res) {
  if (!is.null(res)) {
    res$setHeader("Cache-Control", "public, max-age=3600, stale-while-revalidate=86400")
  }
  invisible(NULL)
}

seo_response <- function(payload, res = NULL) {
  set_seo_cache_headers(res)
  if (!is.null(payload$status) && identical(as.integer(payload$status), 404L) && !is.null(res)) {
    res$status <- 404L
  }
  payload
}

#* List public SEO routes
#*
#* @tag seo
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @response 200 OK. Public route records for prerendering.
#*
#* @get /routes
function(req, res) {
  seo_response(svc_seo_routes(conn = pool), res)
}

#* Get public SEO payload for a gene page
#*
#* @tag seo
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @param symbol Gene symbol.
#* @response 200 OK. Gene SEO payload.
#* @response 404 Not Found. Gene was not found.
#*
#* @get /gene/<symbol>
function(symbol, req, res) {
  seo_response(svc_seo_gene(symbol, conn = pool), res)
}

#* Get public SEO payload for an entity page
#*
#* @tag seo
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @param entity_id SysNDD entity identifier.
#* @response 200 OK. Entity SEO payload.
#* @response 404 Not Found. Entity was not found.
#*
#* @get /entity/<entity_id>
function(entity_id, req, res) {
  seo_response(svc_seo_entity(entity_id, conn = pool), res)
}

#* List public static SEO routes
#*
#* @tag seo
#* @serializer json list(na="string", auto_unbox=TRUE)
#* @response 200 OK. Public static route records.
#*
#* @get /static
function(req, res) {
  seo_response(svc_seo_static(), res)
}
