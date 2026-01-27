// composables/useUrlParsing.ts

/**
 * @fileoverview Composable for handling URL parsing in Vue components.
 *
 * This composable provides methods to convert filter objects to strings and vice versa,
 * and to parse sorting strings. These functionalities are useful for managing URL
 * parameters in the application, facilitating the interaction with API endpoints,
 * and maintaining the state of components based on URL queries.
 *
 * Usage:
 *   import { useUrlParsing } from '@/composables'
 *
 *   export default {
 *     setup() {
 *       const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing()
 *
 *       // Convert filter object to URL string
 *       const filterString = filterObjToStr(filterObject)
 *
 *       // Parse URL string to filter object
 *       const filterObject = filterStrToObj(filterString, standardObject)
 *
 *       // Parse sort string to Bootstrap-Vue-Next format
 *       const { sortBy } = sortStringToVariables('+entity_id')
 *     }
 *   }
 */

/** Filter field structure */
interface FilterField {
  content: string | string[] | null;
  operator: string;
  join_char: string | null;
}

/** Filter object with dynamic keys */
interface FilterObject {
  [key: string]: FilterField;
}

/** Sort result with both new and legacy formats */
interface SortResult {
  sortBy: Array<{ key: string; order: 'asc' | 'desc' }>;
  sortDesc: boolean;
  sortColumn: string;
}

interface UrlParsingMethods {
  filterObjToStr: (filter_object: FilterObject) => string;
  filterStrToObj: (
    filter_string: string | null,
    standard_object: FilterObject,
    split_content?: string[],
    join_char_allow?: string[]
  ) => FilterObject;
  sortStringToVariables: (sort_string: string) => SortResult;
}

export default function useUrlParsing(): UrlParsingMethods {
  /**
   * Converts a filter object into a filter string for URL parameters.
   * This function takes a filter object, removes any null or empty values,
   * and then concatenates each key-value pair into a string.
   *
   * @param filter_object - The filter object to convert.
   * @returns A string representation of the filter object.
   */
  const filterObjToStr = (filter_object: FilterObject): string => {
    // this function checks if a parameter is a valid object
    const isObject = (obj: unknown): obj is Record<string, unknown> => obj === Object(obj);

    // filter the filter object to only contain non null values
    // based on https://stackabuse.com/how-to-filter-an-object-by-key-in-javascript/
    // uses the self defined function "isObject"
    const filter_string_not_empty = Object.keys(filter_object)
      .filter((key) => isObject(filter_object[key]))
      .filter((key) => filter_object[key].content !== null) // <-- remove null values
      .filter((key) => filter_object[key].content !== 'null') // <-- remove null values
      .filter((key) => filter_object[key].content !== '') // <-- remove empty values
      .filter((key) => {
        // <-- remove empty array values (defensive: check length property exists)
        const { content } = filter_object[key];
        if (content === undefined) return false;
        if (typeof content === 'string' || Array.isArray(content)) {
          return content.length !== 0;
        }
        return true; // Keep non-string/non-array values (e.g., numbers, booleans)
      })
      .reduce((obj, key) => Object.assign(obj, {
        [key]: filter_object[key],
      }), {} as FilterObject);

    // join all subobjects to filter string array
    const filter_string_join = Object.keys(filter_string_not_empty).map((key) => `${filter_string_not_empty[key].operator}(${key},${[].concat(filter_string_not_empty[key].content as never).join(filter_string_not_empty[key].join_char || '')})`);

    // join filter string array into one string
    const filter_string = filter_string_join.join(',');

    // return filter string
    return filter_string;
  };

  /**
   * Converts a filter string into a filter object.
   * Parses a filter string, typically from URL parameters, and converts it
   * into a filter object with keys representing the filter fields and values
   * representing the filter criteria.
   *
   * @param filter_string - The filter string to parse.
   * @param standard_object - The standard object structure for the filter.
   * @param split_content - Array of delimiters for splitting the filter string.
   * @param join_char_allow - Array of allowed characters for join operations.
   * @returns An object representation of the filter string.
   */
  const filterStrToObj = (filter_string: string | null, standard_object: FilterObject, _split_content: string[] = [',(?! )'], join_char_allow: string[] = [',']): FilterObject => {
    // check if input is empty/ null
    if (filter_string !== null && filter_string !== 'null' && filter_string !== '') {
      // split input by closing bracket and comma
      const filter_array = filter_string.split('),');

      // define function to check array length
      const arrayLengthOverOne = (input_array: string[], input_operator: string): string | string[] | null => {
        const inputArr = input_array.filter(Boolean);
        if (inputArr.length > 0 && (input_operator === 'any' || input_operator === 'all')) {
          return inputArr;
        } if (inputArr.length === 0) {
          return null;
        }
        return inputArr.join('');
      };

      // define function to assign join_char
      const assignJoinChar = (input_string: string[], input_operator: string, _allowed_join_char: string[]): string | null => {
        if (input_operator === 'any' || input_operator === 'all') {
          return ',';
        }
        return null;
      };

      const filter_object = filter_array.reduce((obj, str, _index) => {
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
      }, {} as FilterObject);

      // return filter object
      const return_object = { ...standard_object, ...filter_object };
      return return_object;
    }
    return standard_object;
  };

  /**
   * Converts a sorting string into an object with sorting variables.
   * Parses a sorting string and extracts sorting direction and field.
   *
   * Returns Bootstrap-Vue-Next array format for sortBy (used by migrated components)
   * plus legacy sortDesc boolean for backward compatibility.
   *
   * @param sort_string - The sorting string to parse (e.g., '+entity_id' or '-symbol').
   * @returns An object containing:
   *   - sortBy: [{ key, order }] - Bootstrap-Vue-Next array format (primary)
   *   - sortDesc: boolean - legacy format for backward compatibility
   *   - sortColumn: string - column key for legacy access
   */
  const sortStringToVariables = (sort_string: string): SortResult => {
    const sortStr = sort_string.trim();
    const isDesc = sortStr.substr(0, 1) === '-';
    const columnKey = sortStr.replace('+', '').replace('-', '');

    return {
      // Bootstrap-Vue-Next array format (primary format for migrated components)
      sortBy: [{ key: columnKey, order: isDesc ? 'desc' : 'asc' }],
      // Legacy format for backward compatibility
      sortDesc: isDesc,
      sortColumn: columnKey,
    };
  };

  return {
    filterObjToStr,
    filterStrToObj,
    sortStringToVariables,
  };
}
