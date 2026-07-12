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

# --- Codex final-review folds (#535 S8): control-char / header / log injection ---

test_that("account_field_has_control_char flags CR/LF/tab, not printable text", {
  # Log- and SMTP-header-injection root cause: a signup field carrying CR/LF is
  # later logged verbatim and/or handed to smtp_send(). This guard rejects them.
  expect_true(account_field_has_control_char("admin\n[FATAL] forged log line"))
  expect_true(account_field_has_control_char("a\r\nBcc: evil@e.com"))
  expect_true(account_field_has_control_char("a\tb"))
  expect_false(account_field_has_control_char("normaluser"))
  # Non-ASCII printable names must pass (no false positive).
  expect_false(account_field_has_control_char("Zoë O'Brien"))
})

test_that("is_valid_email rejects control chars, junk-wrapped, and non-scalar input", {
  expect_true(is_valid_email("test@example.com"))
  expect_true(is_valid_email("First.Last+tag@sub.example.org"))
  # CR/LF -> SMTP header injection into the `to` address must be rejected.
  expect_false(is_valid_email("victim@example.com\r\nBcc: evil@e.com"))
  expect_false(is_valid_email("victim@example.com\nSubject: spoof"))
  # Unanchored old regex matched a valid address embedded in junk; now rejected.
  expect_false(is_valid_email("hello a@b.com world"))
  # Non-scalar / NA must not slip through as a vector of addresses.
  expect_false(is_valid_email(c("a@b.com", "c@d.com")))
  expect_false(is_valid_email(NA_character_))
  expect_false(is_valid_email(NULL))
})

test_that("send_noreply_email rejects CR/LF in recipient, subject, and bcc", {
  # Defense-in-depth choke point: every mail path passes through here, so a
  # control char in any address or the subject is rejected before smtp_send().
  expect_error(
    send_noreply_email("body", "Subject", "a@b.com\r\nBcc: evil@e.com"),
    "recipient"
  )
  expect_error(
    send_noreply_email("body", "Subject\nX-Injected: 1", "a@b.com"),
    "subject"
  )
  expect_error(
    send_noreply_email("body", "Subject", "a@b.com",
      email_blind_copy = "c@d.com\nBcc: evil@e.com"),
    "bcc"
  )
})

test_that("greeting templates tolerate NA/empty/vector user_name without error", {
  # nchar() on NA / length>1 vectors throws; the escaped scalar drives the check.
  expect_no_error(email_password_reset("https://x/reset", NA_character_))
  expect_no_error(email_password_reset("https://x/reset", c("a", "b")))
  expect_no_error(email_password_reset("https://x/reset", character(0)))
  expect_no_error(email_notification("Subj", "<p>hi</p>", NA_character_))
  # A benign name is still personalized.
  out <- email_password_reset("https://x/reset", "Ada")
  expect_true(grepl("Ada", out, fixed = TRUE))
  out2 <- email_notification("Subj", "<p>hi</p>", "Ada")
  expect_true(grepl("Ada", out2, fixed = TRUE))
})
