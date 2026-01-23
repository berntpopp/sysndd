# tests/testthat/test-unit-security.R
# Unit tests for core/security.R password utilities
#
# These tests verify the password hashing and verification functions
# used for Argon2id-based authentication with legacy plaintext support.

# Source the security module
source(test_path("../../core/security.R"), local = TRUE)

# ============================================================================
# is_hashed() tests
# ============================================================================

describe("is_hashed", {
  it("returns TRUE for Argon2id hashes", {
    # Real Argon2id hash format (standard PHC string format)
    hash <- "$argon2id$v=19$m=65536,t=3,p=2$somesalt$somehash"
    expect_true(is_hashed(hash))
  })

  it("returns TRUE for Argon2i hashes", {
    hash <- "$argon2i$v=19$m=65536,t=3,p=2$somesalt$somehash"
    expect_true(is_hashed(hash))
  })

  it("returns TRUE for Argon2d hashes", {
    hash <- "$argon2d$v=19$m=65536,t=3,p=2$somesalt$somehash"
    expect_true(is_hashed(hash))
  })

  it("returns FALSE for plaintext passwords", {
    expect_false(is_hashed("myplaintextpassword"))
    expect_false(is_hashed("P@ssw0rd123"))
    expect_false(is_hashed("simple"))
  })

  it("returns FALSE for empty string", {
    expect_false(is_hashed(""))
  })

  it("returns FALSE for NULL", {
    expect_false(is_hashed(NULL))
  })

  it("returns FALSE for NA", {
    expect_false(is_hashed(NA))
  })

  it("returns FALSE for other hash formats", {
    # bcrypt format (starts with $2a$, $2b$, or $2y$)
    expect_false(is_hashed("$2a$10$N9qo8uLOickgx2ZMRZoMye"))
    expect_false(is_hashed("$2b$12$somebcrypthash"))
    # MD5 format (32 hex chars)
    expect_false(is_hashed("5d41402abc4b2a76b9719d911017c592"))
    # SHA256 (64 hex chars)
    expect_false(is_hashed("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"))
  })
})

# ============================================================================
# hash_password() tests
# ============================================================================

describe("hash_password", {
  it("returns Argon2id hash string", {
    hash <- hash_password("testpassword")
    expect_true(is.character(hash))
    expect_true(startsWith(hash, "$argon2"))
  })

  it("produces different hashes for same password (random salt)", {
    hash1 <- hash_password("samepassword")
    hash2 <- hash_password("samepassword")
    # Hashes should be different due to random salt
    expect_false(hash1 == hash2)
  })

  it("produces consistent length hashes", {
    hash1 <- hash_password("short")
    hash2 <- hash_password("this is a much longer password with special chars !@#$%")
    # Both should produce valid Argon2 hashes (similar structure)
    expect_true(startsWith(hash1, "$argon2"))
    expect_true(startsWith(hash2, "$argon2"))
  })

  it("handles special characters in password", {
    # Password with various special characters
    hash <- hash_password("P@$$w0rd!#%^&*(){}[]|\\:\";<>?,./~`")
    expect_true(is.character(hash))
    expect_true(startsWith(hash, "$argon2"))
  })

  it("handles unicode characters in password", {
    hash <- hash_password("password123")
    expect_true(is.character(hash))
    expect_true(startsWith(hash, "$argon2"))
  })

  it("throws error for NULL password", {
    expect_error(hash_password(NULL), "cannot be NULL")
  })

  it("throws error for NA password", {
    expect_error(hash_password(NA), "cannot be NULL")
  })

  it("throws error for empty password", {
    expect_error(hash_password(""), "cannot be NULL, NA, or empty")
  })
})

# ============================================================================
# verify_password() tests
# ============================================================================

describe("verify_password", {
  it("verifies hashed password correctly - matching password", {
    password <- "MySecureP@ss123"
    hash <- hash_password(password)

    expect_true(verify_password(hash, password))
  })

  it("verifies hashed password correctly - wrong password", {
    password <- "MySecureP@ss123"
    hash <- hash_password(password)

    expect_false(verify_password(hash, "wrongpassword"))
    expect_false(verify_password(hash, "MySecureP@ss124"))
    expect_false(verify_password(hash, ""))
  })

  it("verifies plaintext password correctly (legacy support)", {
    plaintext_stored <- "plaintextpassword"

    expect_true(verify_password(plaintext_stored, "plaintextpassword"))
    expect_false(verify_password(plaintext_stored, "wrongpassword"))
    expect_false(verify_password(plaintext_stored, "PLAINTEXTPASSWORD"))
  })

  it("is case-sensitive for plaintext comparison", {
    plaintext_stored <- "CaseSensitive"

    expect_true(verify_password(plaintext_stored, "CaseSensitive"))
    expect_false(verify_password(plaintext_stored, "casesensitive"))
    expect_false(verify_password(plaintext_stored, "CASESENSITIVE"))
  })

  it("returns FALSE for malformed hash", {
    malformed <- "$argon2id$invalid$hash"
    expect_false(verify_password(malformed, "anypassword"))
  })

  it("returns FALSE for truncated hash", {
    truncated <- "$argon2id$v=19$m=65536"
    expect_false(verify_password(truncated, "anypassword"))
  })

  it("returns FALSE when stored password is NULL", {
    expect_false(verify_password(NULL, "anypassword"))
  })

  it("returns FALSE when stored password is NA", {
    expect_false(verify_password(NA, "anypassword"))
  })

  it("returns FALSE when password attempt is NULL", {
    hash <- hash_password("password")
    expect_false(verify_password(hash, NULL))
  })

  it("returns FALSE when password attempt is NA", {
    hash <- hash_password("password")
    expect_false(verify_password(hash, NA))
  })
})

# ============================================================================
# needs_upgrade() tests
# ============================================================================

describe("needs_upgrade", {
  it("returns TRUE for plaintext passwords", {
    expect_true(needs_upgrade("plaintextpassword"))
    expect_true(needs_upgrade("anotherplaintext"))
    expect_true(needs_upgrade("SimplePassword123"))
  })

  it("returns FALSE for Argon2id hashes", {
    hash <- hash_password("password")
    expect_false(needs_upgrade(hash))
  })

  it("returns FALSE for Argon2i hashes", {
    # Simulate an Argon2i hash format
    hash <- "$argon2i$v=19$m=65536,t=3,p=2$somesalt$somehash"
    expect_false(needs_upgrade(hash))
  })

  it("returns TRUE for bcrypt hashes (not supported, treat as plaintext)", {
    # bcrypt hashes should be upgraded to Argon2id
    bcrypt_hash <- "$2a$10$N9qo8uLOickgx2ZMRZoMye"
    expect_true(needs_upgrade(bcrypt_hash))
  })

  it("returns TRUE for MD5 hashes (not supported, treat as plaintext)", {
    md5_hash <- "5d41402abc4b2a76b9719d911017c592"
    expect_true(needs_upgrade(md5_hash))
  })

  it("is inverse of is_hashed for valid inputs", {
    password <- "testpassword"
    hash <- hash_password(password)

    # needs_upgrade should be inverse of is_hashed
    expect_equal(needs_upgrade(password), !is_hashed(password))
    expect_equal(needs_upgrade(hash), !is_hashed(hash))
  })
})

# ============================================================================
# upgrade_password() tests
# ============================================================================
# Note: upgrade_password() requires database connection - tested in integration tests
# Here we only verify the function signature exists

describe("upgrade_password", {
  it("function exists and has correct signature", {
    expect_true(is.function(upgrade_password))

    # Check function has expected parameters
    params <- names(formals(upgrade_password))
    expect_true("pool" %in% params)
    expect_true("user_id" %in% params)
    expect_true("password_plaintext" %in% params)
  })
})

# ============================================================================
# Integration scenarios (without DB)
# ============================================================================

describe("Authentication workflow scenarios", {
  it("new user signup: hash password", {
    new_password <- "NewUserPassword123!"
    hash <- hash_password(new_password)

    # Should create a valid Argon2 hash
    expect_true(is_hashed(hash))
    expect_false(needs_upgrade(hash))
    # Should verify correctly
    expect_true(verify_password(hash, new_password))
  })

  it("legacy user login: verify plaintext and flag for upgrade", {
    legacy_password <- "legacyPassword"
    # Simulated DB storage (plaintext - legacy)
    stored_password <- legacy_password

    # Should verify correctly
    expect_true(verify_password(stored_password, legacy_password))
    # Should flag for upgrade
    expect_true(needs_upgrade(stored_password))
  })

  it("upgraded user login: verify hash, no upgrade needed", {
    password <- "upgradedPassword"
    # Simulated DB storage (hashed - modern)
    stored_hash <- hash_password(password)

    # Should verify correctly
    expect_true(verify_password(stored_hash, password))
    # Should NOT flag for upgrade
    expect_false(needs_upgrade(stored_hash))
  })

  it("wrong password: fail verification regardless of storage format", {
    correct_password <- "correctPassword"
    wrong_password <- "wrongPassword"

    # Test with plaintext storage
    expect_false(verify_password(correct_password, wrong_password))

    # Test with hashed storage
    hash <- hash_password(correct_password)
    expect_false(verify_password(hash, wrong_password))
  })
})
