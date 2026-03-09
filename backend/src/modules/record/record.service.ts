import { Injectable, Logger } from '@nestjs/common';

import type {
    ChatterDetailsResult,
    ChatterMessage,
    ChatterThreadResult,
    DeleteRecordResult,
    NameSearchResult,
    OnchangeResult,
    RecordActionResult,
    RecordData,
    RecordListResult,
    RecordMutationResult,
    TokenPayload,
} from '@ordo/shared';

import { AdapterFactoryService } from '../../odoo/adapters/adapter-factory.service';
import type { OdooAdapter } from '../../odoo/adapters/odoo-adapter.interface';
import type { OdooSessionContext } from '../../odoo/session/odoo-session.types';
import { OdooSessionStoreService } from '../../odoo/session/odoo-session-store.service';
import { RecordActionDto } from './dto/record-action.dto';
import { ChatterQueryDto } from './dto/chatter-query.dto';
import { CompleteChatterActivityDto } from './dto/complete-chatter-activity.dto';
import { PostChatterNoteDto } from './dto/post-chatter-note.dto';
import { ScheduleChatterActivityDto } from './dto/schedule-chatter-activity.dto';
import { RecordMutationDto } from './dto/record-mutation.dto';
import { RecordOnchangeDto } from './dto/record-onchange.dto';
import { RecordQueryDto } from './dto/record-query.dto';
import { SearchQueryDto } from './dto/search-query.dto';

@Injectable()
export class RecordService {
    private readonly logger = new Logger(RecordService.name);

    constructor(
        private readonly adapterFactory: AdapterFactoryService,
        private readonly sessionStore: OdooSessionStoreService,
    ) { }

    async listRecords(
        currentUser: TokenPayload,
        model: string,
        query: RecordQueryDto,
    ): Promise<RecordListResult> {
        const { session, adapter } = await this.resolveContext(currentUser);
        return adapter.searchRecords(session, model, query);
    }

    async getRecord(
        currentUser: TokenPayload,
        model: string,
        id: number,
        query: RecordQueryDto,
    ): Promise<RecordData> {
        this.logger.debug(`⏳ getRecord ${model}#${id} fields=${query.fields?.join(',') ?? 'ALL'}`);
        const { session, adapter } = await this.resolveContext(currentUser);
        const record = await adapter.getRecord(session, model, id, query.fields);

        // Log field types to diagnose iOS decoding issues
        const fieldTypes: Record<string, string> = {};
        for (const [key, value] of Object.entries(record)) {
            fieldTypes[key] = value === null ? 'null' : Array.isArray(value) ? `array(${(value as unknown[]).length})` : typeof value;
        }
        this.logger.debug(`✅ getRecord ${model}#${id} => ${Object.keys(record).length} fields`);
        this.logger.verbose(`📋 Field types for ${model}#${id}: ${JSON.stringify(fieldTypes)}`);

        return record;
    }

    async getDefaultValues(
        currentUser: TokenPayload,
        model: string,
        query: RecordQueryDto,
    ): Promise<RecordData> {
        const { session, adapter } = await this.resolveContext(currentUser);
        return adapter.getDefaultValues(session, model, query.fields ?? []);
    }

    async search(
        currentUser: TokenPayload,
        model: string,
        query: SearchQueryDto,
    ): Promise<NameSearchResult[]> {
        const { session, adapter } = await this.resolveContext(currentUser);
        return adapter.nameSearch(session, model, query.query ?? '', query.domain, query.limit);
    }

    async listChatter(
        currentUser: TokenPayload,
        model: string,
        id: number,
        query: ChatterQueryDto,
    ): Promise<ChatterThreadResult> {
        const { session, adapter } = await this.resolveContext(currentUser);
        return adapter.listChatter(session, model, id, query.limit, query.before);
    }

    async getChatterDetails(
        currentUser: TokenPayload,
        model: string,
        id: number,
    ): Promise<ChatterDetailsResult> {
        const { session, adapter } = await this.resolveContext(currentUser);
        return adapter.getChatterDetails(session, model, id);
    }

    async postChatterNote(
        currentUser: TokenPayload,
        model: string,
        id: number,
        body: PostChatterNoteDto,
    ): Promise<ChatterMessage> {
        const { session, adapter } = await this.resolveContext(currentUser);
        return adapter.postChatterNote(session, model, id, body.body);
    }

    async followRecord(
        currentUser: TokenPayload,
        model: string,
        id: number,
    ): Promise<ChatterDetailsResult> {
        const { session, adapter } = await this.resolveContext(currentUser);
        return adapter.followRecord(session, model, id);
    }

    async unfollowRecord(
        currentUser: TokenPayload,
        model: string,
        id: number,
    ): Promise<ChatterDetailsResult> {
        const { session, adapter } = await this.resolveContext(currentUser);
        return adapter.unfollowRecord(session, model, id);
    }

    async completeChatterActivity(
        currentUser: TokenPayload,
        model: string,
        id: number,
        activityId: number,
        body: CompleteChatterActivityDto,
    ): Promise<ChatterDetailsResult> {
        const { session, adapter } = await this.resolveContext(currentUser);
        return adapter.completeChatterActivity(session, model, id, activityId, body.feedback);
    }

    async scheduleChatterActivity(
        currentUser: TokenPayload,
        model: string,
        id: number,
        body: ScheduleChatterActivityDto,
    ): Promise<ChatterDetailsResult> {
        const { session, adapter } = await this.resolveContext(currentUser);
        return adapter.scheduleChatterActivity(session, model, id, body.activityTypeId, {
            summary: body.summary,
            note: body.note,
            dateDeadline: body.dateDeadline,
        });
    }

    async createRecord(
        currentUser: TokenPayload,
        model: string,
        body: RecordMutationDto,
    ): Promise<RecordMutationResult> {
        const { session, adapter } = await this.resolveContext(currentUser);
        const id = await adapter.createRecord(session, model, body.values);
        const record = await adapter.getRecord(session, model, id, body.fields);

        return { id, record };
    }

    async runOnchange(
        currentUser: TokenPayload,
        model: string,
        body: RecordOnchangeDto,
    ): Promise<OnchangeResult> {
        const { session, adapter } = await this.resolveContext(currentUser);
        return adapter.runOnchange(session, model, body);
    }

    async updateRecord(
        currentUser: TokenPayload,
        model: string,
        id: number,
        body: RecordMutationDto,
    ): Promise<RecordMutationResult> {
        const { session, adapter } = await this.resolveContext(currentUser);
        await adapter.updateRecord(session, model, id, body.values);
        const record = await adapter.getRecord(session, model, id, body.fields);

        return { id, record };
    }

    async deleteRecord(
        currentUser: TokenPayload,
        model: string,
        id: number,
    ): Promise<DeleteRecordResult> {
        const { session, adapter } = await this.resolveContext(currentUser);
        await adapter.deleteRecord(session, model, id);

        return { id, deleted: true };
    }

    async runRecordAction(
        currentUser: TokenPayload,
        model: string,
        id: number,
        actionName: string,
        body: RecordActionDto,
    ): Promise<RecordActionResult> {
        const { session, adapter } = await this.resolveContext(currentUser);
        const rawResult = await adapter.runRecordAction(session, model, id, actionName);
        const changed = rawResult !== false;

        return {
            id,
            changed,
            record: body.fields?.length
                ? await adapter.getRecord(session, model, id, body.fields)
                : undefined,
        };
    }

    private async resolveContext(currentUser: TokenPayload): Promise<{
        session: OdooSessionContext;
        adapter: OdooAdapter;
    }> {
        return {
            session: await this.sessionStore.getOrThrow(currentUser.sessionHandle),
            adapter: this.adapterFactory.getAdapter(currentUser.version),
        };
    }
}