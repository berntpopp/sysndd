// views/admin/composables/useLeaderboardData.ts
import { ref } from 'vue';
import { safeArray, unwrapScalar } from '@/utils/apiUtils';
import { getContributorLeaderboard, getRereviewLeaderboard } from '@/api/statistics';
import type { LeaderboardParams } from '@/api/statistics';

interface ContributorData {
  user_name: string;
  entity_count: number;
}

interface ReReviewLeaderboardData {
  user_name: string;
  total_assigned: number;
  submitted_count: number;
  approved_count: number;
}

export function useLeaderboardData(
  makeToast: (msg: unknown, title: string, variant: string) => void
) {
  const leaderboardData = ref<ContributorData[]>([]);
  const reReviewLeaderboardData = ref<ReReviewLeaderboardData[]>([]);
  const totalContributors = ref(0);
  const loadingLeaderboard = ref(false);
  const loadingReReview = ref(false);

  const leaderboardScope = ref<'all_time' | 'range'>('all_time');
  const reReviewLeaderboardScope = ref<'all_time' | 'range'>('all_time');

  async function fetchLeaderboard(startDate: string, endDate: string): Promise<void> {
    loadingLeaderboard.value = true;
    try {
      const params: LeaderboardParams = {
        top: 10,
        scope: leaderboardScope.value,
      };
      if (leaderboardScope.value === 'range') {
        params.start_date = startDate;
        params.end_date = endDate;
      }

      const response = await getContributorLeaderboard(params);

      const data = safeArray<{ display_name: string; entity_count: number }>(response?.data);
      leaderboardData.value = data.map((item) => ({
        user_name: item.display_name || 'Unknown',
        entity_count: item.entity_count,
      }));

      if (response?.meta?.total_contributors) {
        totalContributors.value = unwrapScalar(response.meta.total_contributors, 0)!;
      }
    } catch (error) {
      console.error('Failed to fetch leaderboard:', error);
      makeToast('Failed to fetch leaderboard data', 'Error', 'danger');
      leaderboardData.value = [];
    } finally {
      loadingLeaderboard.value = false;
    }
  }

  async function fetchReReviewLeaderboard(startDate: string, endDate: string): Promise<void> {
    loadingReReview.value = true;
    try {
      const params: LeaderboardParams = {
        top: 10,
        scope: reReviewLeaderboardScope.value,
      };
      if (reReviewLeaderboardScope.value === 'range') {
        params.start_date = startDate;
        params.end_date = endDate;
      }

      const response = await getRereviewLeaderboard(params);

      const data = safeArray<{
        display_name: string;
        total_assigned: number;
        submitted_count: number;
        approved_count: number;
      }>(response?.data);

      reReviewLeaderboardData.value = data.map((item) => ({
        user_name: item.display_name || 'Unknown',
        total_assigned: item.total_assigned ?? 0,
        submitted_count: item.submitted_count ?? 0,
        approved_count: item.approved_count ?? 0,
      }));
    } catch (error) {
      console.error('Failed to fetch re-review leaderboard:', error);
      makeToast('Failed to fetch re-review leaderboard data', 'Error', 'danger');
      reReviewLeaderboardData.value = [];
    } finally {
      loadingReReview.value = false;
    }
  }

  return {
    leaderboardData,
    reReviewLeaderboardData,
    totalContributors,
    loadingLeaderboard,
    loadingReReview,
    leaderboardScope,
    reReviewLeaderboardScope,
    fetchLeaderboard,
    fetchReReviewLeaderboard,
  };
}
