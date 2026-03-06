import { Injectable } from '@nestjs/common';

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
        const session = this.sessionStore.getOrThrow(currentUser.sessionHandle);
        const adapter = this.adapterFactory.getAdapter(currentUser.version);
        return adapter.getRecord(session, model, id, query.fields);
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