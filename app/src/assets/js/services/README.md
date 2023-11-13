# Services Subfolder

This subfolder within the project contains various service files that encapsulate specific functionalities, particularly related to API interactions and data handling. These services abstract complex logic and API calls, making them reusable across different components of the application.

## Current Services

### apiService.js

The `apiService.js` file is a service module that provides functions to make asynchronous HTTP requests using axios. It includes methods to fetch different types of data from the API, such as statistics, news, and search results. This service centralizes API calls, ensuring consistency and maintainability.

- `fetchStatistics(type)`: Fetches statistical data based on the provided type.
- `fetchNews(n)`: Retrieves the latest news, with the number of items specified by `n`.
- `fetchSearchInfo(searchInput)`: Performs a search operation based on the provided input.

The service utilizes URLs defined in the `url_constants.js` file, ensuring that API endpoints are managed centrally and can be updated easily.