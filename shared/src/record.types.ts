export type RecordData = Record<string, unknown>;

export interface OnchangeRequest {
    values: RecordData;
    triggerField: string;
    recordId?: number;
    fields?: string[];
}

export interface OnchangeWarning {
    title: string;
    message: string;
    type?: 'warning' | 'info';
}

export interface OnchangeResult {
    values: RecordData;
    warnings?: OnchangeWarning[];
    domains?: Record<string, unknown>;
}

export interface RecordMutationRequest {
    values: RecordData;
    fields?: string[];
}

export interface RecordActionRequest {
    fields?: string[];
}

export interface RecordMutationResult {
    id: number;
    record: RecordData;
}

export interface DeleteRecordResult {
    id: number;
    deleted: true;
}

export interface RecordActionResult {
    id: number;
    changed: boolean;
    record?: RecordData;
}

export interface SyncOperation {
    id: string;
    model: string;
    action: 'create' | 'write' | 'unlink';
    recordId?: number;
    data: RecordData;
    timestamp: string;
    status: 'pending' | 'syncing' | 'conflict' | 'done' | 'failed';
    retryCount: number;
    serverWriteDate?: string;
}

export interface RecordListQuery {
    domain?: unknown[];
    fields?: string[];
    limit?: number;
    offset?: number;
    order?: string;
}

export interface RecordListResult {
    items: RecordData[];
    limit: number;
    offset: number;
}

export interface NameSearchResult {
    id: number;
    name: string;
}