// assets/js/functions.js

/**
 * @fileoverview Utility functions for object manipulation and filtering.
 *
 * This file includes a custom extension to the Object class, providing a filter method
 * for objects. The filter method allows for creating a new object from an existing one
 * based on a provided predicate function. The implementation draws inspiration from
 * a solution shared on Stack Overflow.
 *
 * @see {@link https://stackoverflow.com/questions/5072136/javascript-filter-for-objects}
 */

/**
 * Extends the Object class with a custom filter method.
 * This method filters the properties of an object based on a predicate function.
 * Useful for filtering objects based on certain conditions. The implementation
 * is inspired by a Stack Overflow solution.
 *
 * @example
 * let originalObj = { a: 5, b: 20, c: 15 };
 * let filteredObj = Object.filter(originalObj, (value) => value > 10);
 * filteredObj will be { b: 20, c: 15 }
 *
 * @param {Object} obj - The object to be filtered.
 * @param {function} predicate - A predicate function to test each property's value.
 * The predicate function receives the value of each property as its argument and
 * should return a boolean indicating whether the property should be included in the
 * filtered object.
 *
 * @returns {Object} A new object with properties that pass the predicate function test.
 * Only the properties for which the predicate function returns `true` are included
 * in the returned object.
 */
Object.filter = (obj, predicate) =>
  Object.assign(
    ...Object.keys(obj)
      .filter((key) => predicate(obj[key]))
      .map((key) => ({ [key]: obj[key] }))
  );
