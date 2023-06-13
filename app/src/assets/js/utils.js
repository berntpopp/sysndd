// utils.js
export default {
  // Function to truncate a string to a specified length.
  // If the string is longer than the specified length, it adds '...' to the end.
  truncate(str, n) {
    return str.length > n ? `${str.substr(0, n - 1)}...` : str;
  },
};
