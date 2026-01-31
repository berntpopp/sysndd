# Password Reset Security Fix Plan

## Overview

This plan addresses security vulnerabilities in the SysNDD password reset implementation to bring it in line with [OWASP Forgot Password Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html) and [OWASP API Security Top 10](https://owasp.org/API-Security/editions/2023/en/0xa2-broken-authentication/) best practices.

## Current Issues

### Issue 1: Passwords in URL Query Strings (HIGH SEVERITY)
- **Current**: `GET /api/user/password/reset/change?new_pass_1=xxx&new_pass_2=xxx`
- **Risk**: Passwords exposed in server logs, browser history, proxy logs, referrer headers
- **OWASP Violation**: Sensitive data must never be in URLs

### Issue 2: Email in URL Query String (MEDIUM SEVERITY)
- **Current**: `PUT /api/user/password/reset/request?email_request=xxx`
- **Risk**: PII exposed in server logs
- **Best Practice**: Use POST with JSON body for data submission

### Issue 3: Timestamp Storage/Comparison (LOW SEVERITY)
- **Current**: Datetime stored as string, 2-second tolerance hack for comparison
- **Risk**: Potential for timing attacks, code fragility
- **Fix**: Store Unix timestamp directly as integer

## Implementation Plan

### Phase 1: API Endpoint Refactoring

#### 1.1 Password Reset Request Endpoint
**Change**: `PUT /api/user/password/reset/request?email_request=xxx`
**To**: `POST /api/user/password/reset/request` with JSON body

```r
# Before (user_endpoints.R)
#* @put password/reset/request
function(req, res, email_request = "") { ... }

# After
#* @post password/reset/request
#* @param req:object Request object with JSON body containing email
function(req, res) {
  body <- jsonlite::fromJSON(req$postBody)
  email_request <- body$email
  ...
}
```

#### 1.2 Password Reset Change Endpoint
**Change**: `GET /api/user/password/reset/change?new_pass_1=xxx&new_pass_2=xxx`
**To**: `POST /api/user/password/reset/change` with JSON body

```r
# Before
#* @get password/reset/change
function(req, res, new_pass_1 = "", new_pass_2 = "") { ... }

# After
#* @post password/reset/change
#* @param req:object Request with Bearer token and JSON body
function(req, res) {
  body <- jsonlite::fromJSON(req$postBody)
  new_pass_1 <- body$password
  new_pass_2 <- body$password_confirm
  ...
}
```

### Phase 2: Frontend Updates

#### 2.1 PasswordResetView.vue - Request Form
```javascript
// Before
const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/password/reset/request?email_request=${this.emailEntry}`;
const response = await this.axios.put(apiUrl);

// After
const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/password/reset/request`;
const response = await this.axios.post(apiUrl, { email: this.emailEntry });
```

#### 2.2 PasswordResetView.vue - Password Change
```javascript
// Before
const apiUrl = `...?new_pass_1=${this.newPasswordEntry}&new_pass_2=${this.newPasswordRepeat}`;
await this.axios.get(apiUrl, { headers: { Authorization: `Bearer ${token}` } });

// After
const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/password/reset/change`;
await this.axios.post(apiUrl, {
  password: this.newPasswordEntry,
  password_confirm: this.newPasswordRepeat
}, {
  headers: { Authorization: `Bearer ${token}` }
});
```

### Phase 3: Timestamp Handling Fix

#### 3.1 Store Unix Timestamp
The `password_reset_date` column stores datetime strings which cause rounding issues when comparing with JWT timestamps.

**Option A**: Change column to store Unix timestamp as VARCHAR
```sql
-- No schema change needed, just store integer as string
-- In R: user_update(user_id, list(password_reset_date = as.character(as.integer(Sys.time()))))
```

**Option B (Recommended)**: Keep datetime but fix comparison
```r
# Ensure consistent timezone handling
timestamp_request <- as.POSIXct(Sys.time(), tz = "UTC")
timestamp_iat <- as.integer(timestamp_request)

# Store formatted datetime that includes seconds
user_update(user_id, list(
  password_reset_date = format(timestamp_request, "%Y-%m-%d %H:%M:%S")
))
```

### Phase 4: Additional Security Enhancements

#### 4.1 Add Referrer-Policy Header
```r
# In API response headers
res$setHeader("Referrer-Policy", "no-referrer")
```

#### 4.2 Consistent Response Messages
Ensure same response for valid/invalid emails to prevent enumeration:
```r
# Always return same message
return(list(message = "If this email exists, a reset link has been sent."))
```

## Files to Modify

| File | Changes |
|------|---------|
| `api/endpoints/user_endpoints.R` | Change endpoints from GET/PUT+query to POST+body |
| `app/src/views/PasswordResetView.vue` | Update axios calls to use POST with JSON body |
| `api/core/middleware.R` | Add Referrer-Policy header (optional) |

## Testing Plan

1. **API Tests**
   - Test POST endpoints accept JSON body
   - Verify passwords not logged
   - Verify consistent response for valid/invalid emails

2. **Frontend Tests (Playwright)**
   - Request password reset via form
   - Complete password change flow
   - Login with new password

3. **Security Tests**
   - Verify no sensitive data in server logs
   - Test rate limiting (if implemented)
   - Verify token expiration works

## Implementation Order

1. [ ] Update API endpoints (user_endpoints.R)
2. [ ] Update frontend (PasswordResetView.vue)
3. [ ] Test API directly with curl
4. [ ] Test frontend with Playwright
5. [ ] Commit changes with descriptive message

## References

- [OWASP Forgot Password Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [OWASP API Security Top 10 - Broken Authentication](https://owasp.org/API-Security/editions/2023/en/0xa2-broken-authentication/)

## Estimated Changes

- ~50 lines API changes
- ~20 lines frontend changes
- No database schema changes required
