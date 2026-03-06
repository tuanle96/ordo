export type RecordData = Record<string, unknown>;

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