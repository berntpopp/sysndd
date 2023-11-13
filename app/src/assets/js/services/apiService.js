// apiService.js

/**
 * @fileoverview A service module for making API requests.
 *
 * This module provides functions to interact with various endpoints of the application's API.
 * It abstracts API calls related to fetching statistics, news, and search information,
 * providing a clean interface for these operations within the Vue components.
 * It leverages axios for making HTTP requests and uses constants for API URLs to avoid hardcoding.
 */

import axios from 'axios';

// Importing URLs from a constants file to avoid hardcoding them in this component
import URLS from '@/assets/js/constants/url_constants';

export default {
  /**
   * Fetches statistical data based on a specified type.
   * @async
   * @param {string} type - The type of statistics to fetch.
   * @returns {Promise<Object>} A promise resolving to the statistical data.
   */
  async fetchStatistics(type) {
    const url = `${URLS.API_URL}/api/statistics/category_count?type=${type}`;
    const response = await axios.get(url);
    return response.data;
  },

  /**
   * Fetches the latest news items.
   * @async
   * @param {number} n - The number of news items to fetch.
   * @returns {Promise<Object>} A promise resolving to the latest news items.
   */
  async fetchNews(n) {
    const url = `${URLS.API_URL}/api/statistics/news?n=${n}`;
    const response = await axios.get(url);
    return response.data;
  },

  /**
   * Fetches search information based on a given input.
   * @async
   * @param {string} searchInput - The input to use for the search.
   * @returns {Promise<Object>} A promise resolving to the search results.
   */
  async fetchSearchInfo(searchInput) {
    const url = `${URLS.API_URL}/api/search/${searchInput}?helper=true`;
    const response = await axios.get(url);
    return response.data;
  },
};
