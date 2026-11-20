// Mirrors the API's password_meets_complexity (api/functions/user-endpoint-helpers.R);
// pair with 'min:8' for its length check.
export function passwordComplexity(value: unknown): true | string {
  if (!value) return true;
  const regex = /(?=.*[!@#$%^&*])(?=.*[A-Z])(?=.*[a-z])(?=.*[\d])/;
  if (!regex.test(String(value))) {
    return 'Password must contain at least one uppercase, one lowercase, one number, and one special character (!@#$%^&*)';
  }
  return true;
}
