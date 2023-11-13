# Mixins Subfolder

This subfolder contains various Vue.js mixins used throughout the application. Mixins are a flexible way to distribute reusable functionalities for Vue components. Below is a description of each mixin available in this subfolder.

## colorAndSymbolsMixin.js

This mixin (`colorAndSymbolsMixin.js`) provides data properties related to styling and symbols. It includes various styles and icons configurations used across different components in the application. For instance, it defines styles for categories, user roles, data age, and more, as well as icons for different boolean states like `Yes` or `No`.

## textMixin.js

The `textMixin.js` file offers a centralized place for text-related data properties. It includes various text representations for different application states, such as `ndd_icon_text` for neurodevelopmental disorders (NDD) associated states, `inheritance_short_text` for inheritance types, and more. This mixin helps in managing and updating text content efficiently.

## toastMixin.js

`toastMixin.js` provides a method `makeToast` used for displaying toast notifications. It simplifies showing alerts and informative messages throughout the application. It supports custom titles, message contents, styles (variants), positions, and auto-hide functionalities.

## urlParsingMixin.js

This mixin (`urlParsingMixin.js`) contains methods for URL parameter parsing and string manipulation, specifically for filter and sort functionalities. It includes `filterObjToStr` for converting filter objects to strings, `filterStrToObj` for the reverse process, and `sortStringToVariables` for handling sort parameters. These methods are crucial for managing URL parameters in data fetching operations.

Each mixin is designed to be reusable and can be easily integrated into Vue components to enhance their functionalities.
