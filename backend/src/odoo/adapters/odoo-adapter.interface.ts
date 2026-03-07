import type {
    MobileFormSchema,
    NameSearchResult,
    RecordData,
    RecordListQuery,
    RecordListResult,
} from '@ordo/shared';

import type { OdooSessionContext } from '../session/odoo-session.types';

export interface OdooAdapter {
    readonly version: string;
    getFormSchema(session: OdooSessionContext, model: string): Promise<MobileFormSchema>;
    createRecord(
        session: OdooSessionContext,
        model: string,
        values: RecordData,
    ): Promise<number>;
    updateRecord(
        session: OdooSessionContext,
        model: string,
        id: number,
        values: RecordData,
    ): Promise<boolean>;
    deleteRecord(
        session: OdooSessionContext,
        model: string,
        id: number,
    ): Promise<boolean>;
    runRecordAction(
        session: OdooSessionContext,
        model: string,
        id: number,
        actionName: string,
    ): Promise<unknown>;
    getRecord(
        session: OdooSessionContext,
        model: string,
        id: number,
        fields?: string[],
    ): Promise<RecordData>;
    searchRecords(
        session: OdooSessionContext,
        model: string,
        query: RecordListQuery,
    ): Promise<RecordListResult>;
    nameSearch(
        session: OdooSessionContext,
        model: string,
        query: string,
        domain?: unknown[],
        limit?: number,
    ): Promise<NameSearchResult[]>;
}