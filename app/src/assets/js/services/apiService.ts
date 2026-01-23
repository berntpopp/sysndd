// apiService.ts

/**
 * @fileoverview A service module for making API requests.
 *
 * This module provides functions to interact with various endpoints of the application's API.
 * It abstracts API calls related to fetching statistics, news, and search information,
 * providing a clean interface for these operations within the Vue components.
 * It leverages axios for making HTTP requests and uses constants for API URLs to avoid hardcoding.
 */

import axios from 'axios';
import type { AxiosResponse } from 'axios';

// Importing URLs from a constants file to avoid hardcoding them in this component
import URLS from '@/assets/js/constants/url_constants';

// Import API response types
import type {
  StatisticsResponse,
  NewsResponse,
  SearchResponse,
} from '@/types/api';

/**
 * API Service class for making typed API requests
 */
class ApiService {
  /**
   * Fetches statistical data based on a specified type.
   * @async
   * @param type - The type of statistics to fetch.
   * @returns A promise resolving to the statistical data.
   */
  async fetchStatistics(type: string): Promise<StatisticsResponse> {
    const url = `${URLS.API_URL}/statistics/category_count?type=${type}`;
    const response: AxiosResponse<StatisticsResponse> = await axios.get(url);
    return response.data;
  }

  /**
   * Fetches the latest news items.
   * @async
   * @param n - The number of news items to fetch.
   * @returns A promise resolving to the latest news items.
   */
  async fetchNews(n: number): Promise<NewsResponse> {
    const url = `${URLS.API_URL}/statistics/news?n=${n}`;
    const response: AxiosResponse<NewsResponse> = await axios.get(url);
    return response.data;
  }

  /**
   * Fetches search information based on a given input.
   * @async
   * @param searchInput - The input to use for the search.
   * @returns A promise resolving to the search results.
   */
  async fetchSearchInfo(searchInput: string): Promise<SearchResponse> {
    const url = `${URLS.API_URL}/search/${searchInput}?helper=true`;
    const response: AxiosResponse<SearchResponse> = await axios.get(url);
    return response.data;
  }
}

// Export a singleton instance for backward compatibility
const apiService = new ApiService();
export default apiService;

// Also export the class for future use
export { ApiService };
