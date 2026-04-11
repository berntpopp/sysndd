structure(list(method = "GET", url = "https://www.ncbi.nlm.nih.gov/research/pubtator3-api/search/?text=xyzzy12345nonexistent98765&page=1", 
    status_code = 200L, headers = structure(list(`strict-transport-security` = "max-age=31536000; includeSubDomains; preload", 
        `referrer-policy` = "origin-when-cross-origin", `content-security-policy` = "upgrade-insecure-requests", 
        date = "Sat, 11 Apr 2026 16:13:30 GMT", vary = "Accept,origin", 
        allow = "GET, HEAD, OPTIONS", server = "nginx", `content-type` = "application/json", 
        `referrer-policy` = "same-origin", `x-frame-options` = "DENY", 
        `x-content-type-options` = "nosniff", `cross-origin-opener-policy` = "same-origin", 
        `content-encoding` = "gzip", `content-length` = "94", 
        `set-cookie` = "ncbi_sid=D056F9739DA6F9B3_0534SID; Domain=.nih.gov; expires=Sun, 11 Apr 2027 16:13:30 GMT; Max-Age=31536000; Path=/", 
        `x-ua-compatible` = "IE=Edge", `x-xss-protection` = "1; mode=block"), class = "httr2_headers"), 
    body = charToRaw("{\"results\":[],\"facets\":{},\"page_size\":10,\"current\":1,\"count\":0,\"total_pages\":0}"), 
    timing = c(redirect = 0, namelookup = 2.8e-05, connect = 0.108863, 
    pretransfer = 0.313213, starttransfer = 1.645081, total = 1.645117
    ), cache = new.env(parent = emptyenv())), class = "httr2_response")
