<!-- views/curate/ApproveStatus.vue -->
<!--
  ApproveStatus.vue (Phase E.E6 — `converge-approve-status`, exit #13).

  Thin wrapper: delegates all presentation to `ApprovalTableView.vue` and
  keeps only the HTTP layer + the exposed surface the C3 spec drives via
  `wrapper.vm.<member>` (`items_StatusTable`, `totalRows`, `approveModal`,
  `status_info`, `infoApproveStatus`, `handleStatusOk`).
-->
<template>
  <AuthenticatedPageShell
    title="Approve Statuses"
    content-class="authenticated-route-content"
    full-width
  >
    <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <ApprovalTableView
            ref="tableView"
            :items="items_StatusTable"
            :loading="loading_status_approve"
            :busy="isBusy"
            :approve-title="approveModal.title"
            :dismiss-title="dismissModal.title"
            :approve-has-duplicates="approveModal.hasDuplicates"
            :loading-edit="loading_status_modal"
            :status-info="status_info"
            :entity-info="entity_info"
            :status-options="status_options"
            :approve-all-selected="approve_all_selected"
            :user-icon="user_icon"
            :user-style="user_style"
            :stoplights-style="stoplights_style"
            @approve-status="infoApproveStatus($event, 0, null)"
            @dismiss-status="infoDismissStatus($event, 0, null)"
            @edit-status="infoStatus($event, 0, null)"
            @approve-all="checkAllApprove"
            @approve-ok="handleStatusOk(null)"
            @dismiss-ok="handleDismissOk(null)"
            @edit-ok="submitStatusChange"
            @approve-all-ok="handleAllStatusOk"
            @refresh="loadStatusTableData"
            @items-synced="
              (rows) => {
                totalRows = rows.length;
              }
            "
            @update:status-info="status_info = $event"
            @update:approve-all-selected="approve_all_selected = $event"
          />
        </BCol>
      </BRow>
      <AriaLiveRegion :message="a11yMessage" :politeness="a11yPoliteness" />
    </BContainer>
  </div>
  </AuthenticatedPageShell>
</template>
<script setup lang="ts">
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import { onMounted, reactive, ref, getCurrentInstance } from 'vue';
import type { AxiosInstance } from 'axios';
import { apiClient } from '@/api/client';
import { useToast, useColorAndSymbols, useAriaLive } from '@/composables';
import { useUiStore } from '@/stores/ui';
import AriaLiveRegion from '@/components/accessibility/AriaLiveRegion.vue';
import ApprovalTableView from '@/components/ApprovalTableView.vue';
import Status from '@/assets/js/classes/submission/submissionStatus';
import type { StatusInfoShape, EntityInfoShape } from '@/components/review/EditStatusModal.vue';

const { makeToast } = useToast();
const { stoplights_style, user_style, user_icon } = useColorAndSymbols();
const { message: a11yMessage, politeness: a11yPoliteness, announce } = useAriaLive();
const uiStore = useUiStore();
const instance = getCurrentInstance();
// `this.axios` (Vue Test Utils mocks) wins over the production fallback so
// the C3 spec's mocked-axios pattern keeps working. Production fallback is
// `apiClient.raw` — same singleton, same 401 + Bearer interceptors.
const ax = (): AxiosInstance =>
  (instance?.proxy as unknown as { axios?: AxiosInstance } | undefined)?.axios ??
  (apiClient.raw as unknown as AxiosInstance);
const apiBase = (): string => import.meta.env.VITE_API_URL || '';
// v11.0 closeout F2a: the inline Bearer-header construction on every
// authed PUT has been removed. The `apiClient` request interceptor
// (`@/api/client`) reads `useAuth().token.value` and injects the
// Authorization header on every outbound call against the shared axios
// singleton; every `ax()` call here routes through that same singleton
// (either via the `this.axios` test proxy or `axios` itself). See
// `.planning/_archive/legacy-plans/v11.0/closeout.md` §3 F2a.
const initialEntity: EntityInfoShape = {
  entity_id: 0,
  symbol: '',
  hgnc_id: '',
  disease_ontology_id_version: '',
  disease_ontology_name: '',
  hpo_mode_of_inheritance_term_name: '',
  hpo_mode_of_inheritance_term: '',
};
const items_StatusTable = ref<Array<Record<string, unknown>>>([]);
const totalRows = ref(0);
const isBusy = ref(true);
const loading_status_approve = ref(true);
const loading_status_modal = ref(true);
const approve_all_selected = ref(false);
const status_options = ref<Array<{ id: number | string; label: string }>>([]);
const status_info = ref<StatusInfoShape>(new Status() as unknown as StatusInfoShape);
const entity_info = ref<EntityInfoShape>({ ...initialEntity });
const approveModal = reactive({ id: 'approve-modal', title: '', hasDuplicates: false });
const dismissModal = reactive({ id: 'dismiss-modal', title: '', statusId: null as number | null });
const statusModal = reactive({ id: 'status-modal', title: '' });
const tableView = ref<{ showModal: (id: string) => void } | null>(null);
const showModal = (id: string) => tableView.value?.showModal(id);
async function loadStatusList(): Promise<void> {
  try {
    const r = await ax().get(`${apiBase()}/api/list/status?tree=true`);
    status_options.value = r.data;
    loadStatusTableData();
  } catch (e) {
    makeToast(e, 'Error', 'danger');
  }
}
async function loadStatusTableData(): Promise<void> {
  isBusy.value = true;
  try {
    const r = await ax().get(`${apiBase()}/api/status`);
    items_StatusTable.value = r.data;
    totalRows.value = r.data.length;
  } catch (e) {
    makeToast(e, 'Error', 'danger');
  } finally {
    uiStore.requestScrollbarUpdate();
    isBusy.value = false;
    loading_status_approve.value = false;
  }
}
async function loadStatusInfo(status_id: number): Promise<void> {
  loading_status_modal.value = true;
  try {
    const r = await ax().get(`${apiBase()}/api/status/${status_id}`);
    const row = r.data[0];
    const s = new Status(
      row.category_id,
      row.comment,
      row.problematic
    ) as unknown as StatusInfoShape;
    s.status_id = row.status_id;
    s.status_user_role = row.status_user_role;
    s.status_user_name = row.status_user_name;
    s.entity_id = row.entity_id;
    status_info.value = s;
  } catch (e) {
    makeToast(e, 'Error', 'danger');
  } finally {
    loading_status_modal.value = false;
  }
}
async function getEntity(entity_id: number): Promise<void> {
  try {
    const r = await ax().get(`${apiBase()}/api/entity?filter=equals(entity_id,${entity_id})`);
    if (r.data.data?.[0]) entity_info.value = r.data.data[0];
  } catch (e) {
    makeToast(e, 'Error', 'danger');
  }
}
function infoApproveStatus(item: Record<string, unknown>, _i: number, _b: unknown): void {
  approveModal.title = `sysndd:${item.entity_id}`;
  approveModal.hasDuplicates = item.duplicate === 'yes';
  loadStatusInfo(item.status_id as number);
  showModal(approveModal.id);
}
function infoDismissStatus(item: Record<string, unknown>, _i: number, _b: unknown): void {
  dismissModal.title = `sysndd:${item.entity_id}`;
  dismissModal.statusId = (item.status_id as number) ?? null;
  showModal(dismissModal.id);
}
function infoStatus(item: Record<string, unknown>, _i: number, _b: unknown): void {
  statusModal.title = `sysndd:${item.entity_id}`;
  getEntity(item.entity_id as number);
  loadStatusInfo(item.status_id as number);
  showModal(statusModal.id);
}
async function handleStatusOk(_evt: unknown): Promise<void> {
  try {
    await ax().put(
      `${apiBase()}/api/status/approve/${status_info.value.status_id}?status_ok=true`,
      {}
    );
    announce('Status approved successfully');
    loadStatusTableData();
  } catch (e) {
    makeToast(e, 'Error', 'danger');
    announce('Error approving status', 'assertive');
  }
}
async function handleDismissOk(_evt: unknown): Promise<void> {
  try {
    await ax().put(`${apiBase()}/api/status/approve/${dismissModal.statusId}?status_ok=false`, {});
    announce('Status dismissed successfully');
    loadStatusTableData();
  } catch (e) {
    makeToast(e, 'Error', 'danger');
    announce('Error dismissing status', 'assertive');
  }
}
async function submitStatusChange(): Promise<void> {
  isBusy.value = true;
  try {
    status_info.value.status_user_name = null;
    status_info.value.status_user_role = null;
    status_info.value.entity_id = null;
    await ax().put(`${apiBase()}/api/status/update`, { status_json: status_info.value });
    const m = 'The new status for this entity has been submitted successfully.';
    makeToast(m, 'Success', 'success');
    announce(m);
    status_info.value = new Status() as unknown as StatusInfoShape;
    loadStatusTableData();
  } catch (e) {
    makeToast(e, 'Error', 'danger');
    announce('Error submitting status', 'assertive');
  } finally {
    isBusy.value = false;
  }
}
async function handleAllStatusOk(): Promise<void> {
  if (!approve_all_selected.value) return;
  try {
    await ax().put(`${apiBase()}/api/status/approve/all?status_ok=true`, {});
    loadStatusTableData();
  } catch (e) {
    makeToast(e, 'Error', 'danger');
  }
}
function checkAllApprove(): void {
  showModal('approveAllModal');
}
onMounted(() => {
  loadStatusList();
});
defineExpose({
  items_StatusTable,
  totalRows,
  approveModal,
  dismissModal,
  statusModal,
  status_info,
  entity_info,
  status_options,
  approve_all_selected,
  infoApproveStatus,
  infoDismissStatus,
  infoStatus,
  handleStatusOk,
  handleDismissOk,
  submitStatusChange,
  handleAllStatusOk,
  checkAllApprove,
  loadStatusTableData,
  loadStatusInfo,
});
</script>
