// assets/js/mixins/urlParsingMixin.js
export default {
  methods: {
    // this function takes a filter object and joins it into one filter string
    filterObjToStr(filter_object) {
      // this function checks if a paramater is a valid object
      const isObject = function(obj) {
        return obj === Object(obj);
      }

      // filter the filter object to only contain non null values
      // based on https://stackabuse.com/how-to-filter-an-object-by-key-in-javascript/
      // uses the self defined function "isObject"
      const filter_string_not_empty = Object.keys(filter_object)
        .filter((key) => isObject(filter_object[key]))
        .filter((key) => filter_object[key].content !== null) //<-- remove null values
        .filter((key) => filter_object[key].content !== "null") //<-- remove null values
        .filter((key) => filter_object[key].content !== '') //<-- remove empty values
        .reduce((obj, key) => {
          return Object.assign(obj, {
            [key]: filter_object[key]
          });
        }, {});

      // join all subobjects to filter string array
      const filter_string_join = Object.keys(filter_string_not_empty).map((key) => filter_string_not_empty[key].operator + "(" + key + "," + [].concat(filter_string_not_empty[key].content).join(filter_string_not_empty[key].join_char) + ")")

      // join filter string array into one string
      const filter_string = filter_string_join.join(",")

      // return filter string
      return filter_string;
    },
    filterStrToObj(filter_string, standard_object, split_content = [",(?! )"], join_char_allow = [","]) {
      // convert input split_content to regex object
      const split_content_regex = new RegExp(split_content.join("|"))

      // check if imput is empty/ null
      if (filter_string !== null && filter_string !== "null" && filter_string !== '') {

        // split input by closing bracket and comma
        const filter_array = filter_string.split("),")

        // define function to check array length
        const arrayLengthOverOne = function(input_array, input_operator) {
          input_array = input_array.filter(Boolean);
          if (input_array.length > 0 && (input_operator === "any" || input_operator === "all")) {
            return input_array;
          } else if (input_array.length === 0) {
            return null;
          } else {
            return input_array.join("");
          }
        }

        // define function to assign join_char
        const assignJoinChar = function(input_string, input_operator, allowed_join_char) {
          if (input_operator === "any" || input_operator === "all") {
            return ",";
          } else {
            return null;
          }
        }

        let filter_object = filter_array.reduce(function (obj, str, index) {
          const [firstPart, secondPart, ...restPart] = str.replace(')', '').split(/\(|,(?! )/g); //<-- replace any trailing brackets and split using regex into object components
          if (firstPart && secondPart && restPart) { //<-- Make sure the key & value are not undefined
            obj[secondPart.replace(/\s+/g, '')] = {
              content: arrayLengthOverOne(restPart, firstPart.trim()),
              operator: firstPart.trim(),
              join_char: assignJoinChar(restPart, firstPart.trim(), join_char_allow)
            };
          }
          return obj;
        }, {});

        // return filter object
        const return_object = Object.assign({}, standard_object, filter_object);
        return return_object;
      } else {
        return standard_object;
      }
    },
    sortStringToVariables(sort_string) {
      sort_string = sort_string.trim()
      let return_object = {
        sortDesc: (sort_string.substr(0, 1) !== '-'),
        sortBy: sort_string.replace('+', '').replace('-', ''),
      }
      return return_object;
    },
  },
}