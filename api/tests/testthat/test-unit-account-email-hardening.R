# Tests for S8 account/email hardening (#535):
#   1. random_password() uses a CSPRNG (openssl::rand_bytes), not the seedable
#      Mersenne-Twister via sample().
#   2. User-controlled fields are HTML-escaped before interpolation into HTML
#      email bodies (stored-XSS-in-email defense).

# Resolve the api dir and source the functions under test (pure — no DB needed).
if (exists("get_api_dir")) {
  api_dir <- get_api_dir()
} else {
  api_dir <- normalizePath(file.path(dirname(getwd()), ".."), mustWork = FALSE)
  if (!file.exists(file.path(api_dir, "functions", "account-helpers.R"))) {
    api_dir <- normalizePath(file.path(getwd(), ".."), mustWork = FALSE)
  }
}
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
source(file.path(api_dir, "functions", "account-helpers.R"), local = FALSE)
source(file.path(api_dir, "functions", "email-templates.R"), local = FALSE)

test_that("random_password() is a CSPRNG (ignores set.seed)", {
  # The old sample()-based generator is reproducible under a fixed seed; a CSPRNG
  # ignores set.seed entirely, so two seeded draws must differ.
  set.seed(1)
  a <- random_password()
  set.seed(1)
  b <- random_password()
  expect_false(identical(a, b))
})

test_that("random_password() keeps its 12-char / 64-char-alphabet contract", {
  alphabet <- c(0:9, letters, LETTERS, "!", "$")
  expect_equal(length(alphabet), 64L)
  for (i in seq_len(50)) {
    pw <- random_password()
    expect_equal(nchar(pw), 12L)
    chars <- strsplit(pw, "")[[1]]
    expect_true(all(chars %in% as.character(alphabet)))
  }
  # 100 draws should be unique (entropy sanity).
  draws <- vapply(1:100, function(x) random_password(), character(1))
  expect_equal(length(unique(draws)), 100L)
})

test_that("registration email HTML-escapes a hostile user_name", {
  out <- email_registration_request(list(
    user_name = "<img src=x onerror=alert(1)>",
    email = "a@b.c",
    first_name = "A",
    family_name = "B"
  ))
  expect_true(grepl("&lt;img", out, fixed = TRUE))
  expect_false(grepl("<img src=x onerror", out, fixed = TRUE))
})

test_that("re-review email attribute-escapes a hostile orcid", {
  out <- email_rereview_request(list(
    user_name = "u",
    email = "a@b.c",
    orcid = "\"><b>"
  ))
  # The quote-and-tag break-out must not survive verbatim in the href/label.
  expect_false(grepl("\"><b>", out, fixed = TRUE))
  expect_true(grepl("&gt;&lt;b&gt;", out, fixed = TRUE))
  # The href attribute must attribute-escape the quote (&quot;) — proving attribute
  # escaping, not merely text escaping (which would leave a dangerous bare quote).
  expect_true(grepl("&quot;", out, fixed = TRUE))
})

test_that("email_escape coerces NULL/NA/non-scalar to empty string", {
  expect_equal(email_escape(NULL), "")
  expect_equal(email_escape(NA), "")
  expect_equal(email_escape(character(0)), "")
  expect_equal(email_escape_attr(NA_character_), "")
  expect_equal(email_escape("<b>"), "&lt;b&gt;")
})

test_that("benign names round-trip through the templates unchanged", {
  out <- email_account_approved("Ada Lovelace", "TempPass1!")
  expect_true(grepl("Ada Lovelace", out, fixed = TRUE))
})
