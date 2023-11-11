/**
 * @fileoverview Utility functions for common operations.
 */

export default {
  /**
   * Truncates a string to a specified length including the ellipsis.
   * If the string is longer than the specified length, it adds '...' to the end.
   *
   * @param {string} str - The string to truncate.
   * @param {number} n - The maximum length of the string including the ellipsis.
   * @returns {string} The truncated string with ellipsis if it exceeds the specified length.
   */
  truncate(str, n) {
    return str.length > n ? `${str.substr(0, n - 3)}...` : str;
  },
};
