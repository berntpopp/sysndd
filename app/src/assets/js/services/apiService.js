// apiService.js
import axios from 'axios';

// Importing URLs from a constants file to avoid hardcoding them in this component
import URLS from '@/assets/js/constants/url_constants';

export default {
  async fetchStatistics(type) {
    const url = `${URLS.API_URL}/api/statistics/category_count?type=${type}`;
    const response = await axios.get(url);
    return response.data;
  },
  async fetchNews(n) {
    const url = `${URLS.API_URL}/api/statistics/news?n=${n}`;
    const response = await axios.get(url);
    return response.data;
  },
  async fetchSearchInfo(searchInput) {
    const url = `${URLS.API_URL}/api/search/${searchInput}?helper=true`;
    const response = await axios.get(url);
    return response.data;
  },
};
