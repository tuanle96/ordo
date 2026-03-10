import type {
    ChatterActivityTypeOption,
    ChatterDetailsResult,
    ChatterMessage,
    ChatterThreadResult,
    MobileFormSchema,
    MobileListSchema,
    NameSearchResult,
    OnchangeRequest,
    OnchangeResult,
    RecordData,
    RecordListQuery,
    RecordListResult,
} from '@app/shared';

import type { BrowseMenuNode, InstalledModuleInfo } from '@app/modules/module/module.types';

import type { OdooSessionContext } from '@app/odoo/session/odoo-session.types';

export interface OdooAdapter {
    readonly version: string;
    getFormSchema(session: OdooSessionContext, model: string): Promise<MobileFormSchema>;
    getListSchema(session: OdooSessionContext, model: string): Promise<MobileListSchema>;
    getDefaultValues(
        session: OdooSessionContext,
        model: string,
        fields: string[],
    ): Promise<RecordData>;
    createRecord(
        session: OdooSessionContext,
        model: string,
        values: RecordData,
    ): Promise<number>;
    runOnchange(
        session: OdooSessionContext,
        model: string,
        request: OnchangeRequest,
    ): Promise<OnchangeResult>;
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
    listChatter(
        session: OdooSessionContext,
        model: string,
        id: number,
        limit?: number,
        before?: number,
    ): Promise<ChatterThreadResult>;
    getChatterDetails(
        session: OdooSessionContext,
        model: string,
        id: number,
    ): Promise<ChatterDetailsResult>;
    postChatterNote(
        session: OdooSessionContext,
        model: string,
        id: number,
        body: string,
    ): Promise<ChatterMessage>;
    followRecord(
        session: OdooSessionContext,
        model: string,
        id: number,
    ): Promise<ChatterDetailsResult>;
    unfollowRecord(
        session: OdooSessionContext,
        model: string,
        id: number,
    ): Promise<ChatterDetailsResult>;
    completeChatterActivity(
        session: OdooSessionContext,
        model: string,
        id: number,
        activityId: number,
        feedback?: string,
    ): Promise<ChatterDetailsResult>;
    scheduleChatterActivity(
        session: OdooSessionContext,
        model: string,
        id: number,
        activityTypeId: number,
        values?: {
            summary?: string;
            note?: string;
            dateDeadline?: string;
        },
    ): Promise<ChatterDetailsResult>;
    getInstalledModules(
        session: OdooSessionContext,
    ): Promise<InstalledModuleInfo[]>;
    getBrowseMenuTree(
        session: OdooSessionContext,
    ): Promise<BrowseMenuNode[]>;
}