import { Injectable, Logger } from '@nestjs/common';

import type {
    NameSearchResult,
    RecordData,
    RecordListResult,
    TokenPayload,
} from '@ordo/shared';

import { AdapterFactoryService } from '../../odoo/adapters/adapter-factory.service';
import { OdooSessionStoreService } from '../../odoo/session/odoo-session-store.service';
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
        const session = this.sessionStore.getOrThrow(currentUser.sessionHandle);
        const adapter = this.adapterFactory.getAdapter(currentUser.version);
        return adapter.searchRecords(session, model, query);
    }

    async getRecord(
        currentUser: TokenPayload,
        model: string,
        id: number,
        query: RecordQueryDto,
    ): Promise<RecordData> {
        this.logger.debug(`⏳ getRecord ${model}#${id} fields=${query.fields?.join(',') ?? 'ALL'}`);
        const session = this.sessionStore.getOrThrow(currentUser.sessionHandle);
        const adapter = this.adapterFactory.getAdapter(currentUser.version);
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

    async search(
        currentUser: TokenPayload,
        model: string,
        query: SearchQueryDto,
    ): Promise<NameSearchResult[]> {
        const session = this.sessionStore.getOrThrow(currentUser.sessionHandle);
        const adapter = this.adapterFactory.getAdapter(currentUser.version);
        return adapter.nameSearch(session, model, query.query ?? '', query.domain, query.limit);
    }
}