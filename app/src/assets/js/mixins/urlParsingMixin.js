// assets/js/mixins/urlParsingMixin.js

/**
 * @fileoverview Mixin for handling URL parsing in Vue components.
 *
 * This mixin provides methods to convert filter objects to strings and vice versa,
 * and to parse sorting strings. These functionalities are useful for managing URL
 * parameters in the application, facilitating the interaction with API endpoints,
 * and maintaining the state of components based on URL queries.
 */

export default {
  methods: {
    /**
     * Converts a filter object into a filter string for URL parameters.
     * This function takes a filter object, removes any null or empty values,
     * and then concatenates each key-value pair into a string.
     *
     * @param {Object} filter_object - The filter object to convert.
     * @returns {string} A string representation of the filter object.
     */
    filterObjToStr(filter_object) {
      // this function checks if a parameter is a valid object
      const isObject = (obj) => obj === Object(obj);

      // filter the filter object to only contain non null values
      // based on https://stackabuse.com/how-to-filter-an-object-by-key-in-javascript/
      // uses the self defined function "isObject"
      const filter_string_not_empty = Object.keys(filter_object)
        .filter((key) => isObject(filter_object[key]))
        .filter((key) => filter_object[key].content !== null) // <-- remove null values
        .filter((key) => filter_object[key].content !== 'null') // <-- remove null values
        .filter((key) => filter_object[key].content !== '') // <-- remove empty values
        .filter((key) => filter_object[key].content.length !== 0) // <-- remove empty array values
        .reduce((obj, key) => Object.assign(obj, {
          [key]: filter_object[key],
        }), {});

      // join all subobjects to filter string array
      const filter_string_join = Object.keys(filter_string_not_empty).map((key) => `${filter_string_not_empty[key].operator}(${key},${[].concat(filter_string_not_empty[key].content).join(filter_string_not_empty[key].join_char)})`);

      // join filter string array into one string
      const filter_string = filter_string_join.join(',');

      // return filter string
      return filter_string;
    },
    /**
   * Converts a filter string into a filter object.
   * Parses a filter string, typically from URL parameters, and converts it
   * into a filter object with keys representing the filter fields and values
   * representing the filter criteria.
   *
   * @param {string} filter_string - The filter string to parse.
   * @param {Object} standard_object - The standard object structure for the filter.
   * @param {string[]} split_content - Array of delimiters for splitting the filter string.
   * @param {string[]} join_char_allow - Array of allowed characters for join operations.
   * @returns {Object} An object representation of the filter string.
   */
    filterStrToObj(filter_string, standard_object, split_content = [',(?! )'], join_char_allow = [',']) {
      // convert input split_content to regex object
      const split_content_regex = new RegExp(split_content.join('|'));

      // check if input is empty/ null
      if (filter_string !== null && filter_string !== 'null' && filter_string !== '') {
        // split input by closing bracket and comma
        const filter_array = filter_string.split('),');

        // define function to check array length
        const arrayLengthOverOne = (input_array, input_operator) => {
          const inputArr = input_array.filter(Boolean);
          if (inputArr.length > 0 && (input_operator === 'any' || input_operator === 'all')) {
            return inputArr;
          } if (inputArr.length === 0) {
            return null;
          }
          return inputArr.join('');
        };

        // define function to assign join_char
        const assignJoinChar = (input_string, input_operator, allowed_join_char) => {
          if (input_operator === 'any' || input_operator === 'all') {
            return ',';
          }
          return null;
        };

        const filter_object = filter_array.reduce((obj, str, index) => {
          const [firstPart, secondPart, ...restPart] = str.replace(')', '').split(/\(|,(?! )/g); // <-- replace any trailing brackets and split using regex into object components
          const objCopy = obj;
          if (firstPart && secondPart && restPart) { // <-- Make sure the key & value are not undefined
            objCopy[secondPart.replace(/\s+/g, '')] = {
              content: arrayLengthOverOne(restPart, firstPart.trim()),
              operator: firstPart.trim(),
              join_char: assignJoinChar(restPart, firstPart.trim(), join_char_allow),
            };
          }
          return objCopy;
        }, {});

        // return filter object
        const return_object = { ...standard_object, ...filter_object };
        return return_object;
      }
      return standard_object;
    },
    /**
   * Converts a sorting string into an object with sorting variables.
   * Parses a sorting string and extracts sorting direction and field.
   *
   * Updated for Bootstrap-Vue-Next: Returns array-based sortBy format.
   *
   * @param {string} sort_string - The sorting string to parse (e.g., '+entity_id' or '-symbol').
   * @returns {Object} An object containing sortBy (array format) for Bootstrap-Vue-Next.
   */
    sortStringToVariables(sort_string) {
      const sortStr = sort_string.trim();
      const isDesc = sortStr.substr(0, 1) === '-';
      const columnKey = sortStr.replace('+', '').replace('-', '');

      // Return Bootstrap-Vue-Next array format
      return {
        sortBy: [{ key: columnKey, order: isDesc ? 'desc' : 'asc' }],
      };
    },
  },
};
