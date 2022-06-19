// assets/js/mixins/urlParsingMixin.js
export default {
  methods: {
    filterStringToObject(filter_string, join_char = '|', operator = 'contains', as_array = 'any,category,hpo_mode_of_inheritance_term,hpo_mode_of_inheritance_term_name,entities_count') {
      // this function converts a filter string from a URL to a filter object
      // define the filter object
      let filter_obj = {};

      // check if empty and handle
      if (filter_string === '' || filter_string === null) {
        filter_obj = { any: null, entity_id: null, symbol: null, disease_ontology_name: null, disease_ontology_id_version: null, hpo_mode_of_inheritance_term_name: null, hpo_mode_of_inheritance_term: null, ndd_phenotype_word: null, category: null };
      } else {
        // replace string to have JSON string
        const filter_replace = decodeURI(filter_string)
          .split('contains(').join('{"')
          .split(')').join('"}')
          .split('},{').join(';')
          .split(', ').join('#') // this handels comma-sapce in string
          .split(',').join('":"')
          .split(';').join(',')
          .split('#').join(', ');

        // parse the JSON string to a JSON object
        filter_obj = JSON.parse(filter_replace);

        // split arrays
        Object.keys(filter_obj).forEach((key) => {
          if (filter_obj[key].includes("|")) {
            filter_obj[key] = filter_obj[key].split("|");
          }
          if (as_array.split(",").includes(key)) {
            filter_obj[key] = [].concat(filter_obj[key]);
          }
        });
      }

      // return the object
      return filter_obj;
    },
    filterObjectToString(filter_object, join_char = '|', operator = 'contains') {
      // filter the filter object to only contain non null values
      const filter_string_not_empty = Object.filter(filter_object, value => (value !== null && value !== "null" && value !== '' && value.length !== 0));

      // iterate over the filtered non null expressions and join array with regex or "|"
      const filter_string_not_empty_join = {};
      Object.keys(filter_string_not_empty).forEach((key) => {
        if (Array.isArray(filter_string_not_empty[key])) {
          filter_string_not_empty_join[key] = filter_string_not_empty[key].join(join_char);
        } else {
          filter_string_not_empty_join[key] = filter_string_not_empty[key];
        }
      });

      // compute the filter string by joining the filter object
      let filter_string = ''
      if (Object.keys(filter_string_not_empty_join).length !== 0) {
        filter_string = operator + '(' + Object.keys(filter_string_not_empty_join).map((key) => [key, filter_string_not_empty_join[key]].join(',')).join('),' + operator + '(') + ')';
      }

      // return string
      return filter_string;
    },
    sortStringToVariables(sort_string) {
      let return_object = {
        sortDesc: (sort_string.substr(0, 1) !== '-'),
        sortBy: sort_string.replace('+', '').replace('-', ''),
      }
      return return_object;
    },
  },
}