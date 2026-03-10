import { Injectable } from '@nestjs/common';

import type { MobileFormSchema, MobileListSchema, TokenPayload } from '@app/shared';

import { SchemaCacheService } from '@app/modules/schema/schema-cache.service';
import { AdapterFactoryService } from '@app/odoo/adapters/adapter-factory.service';
import { OdooSessionStoreService } from '@app/odoo/session/odoo-session-store.service';

@Injectable()
export class SchemaService {
    constructor(
        private readonly adapterFactory: AdapterFactoryService,
        private readonly sessionStore: OdooSessionStoreService,
        private readonly schemaCache: SchemaCacheService,
    ) { }

    async getFormSchema(currentUser: TokenPayload, model: string, fresh = false): Promise<MobileFormSchema> {
        if (!fresh) {
            const cachedSchema = await this.schemaCache.get<MobileFormSchema>(currentUser, 'form', model);
            if (cachedSchema) {
                return cachedSchema;
            }
        }

        const session = await this.sessionStore.getOrThrow(currentUser.sessionHandle);
        const adapter = this.adapterFactory.getAdapter(currentUser.version);
        const schema = await adapter.getFormSchema(session, model);
        await this.schemaCache.set(currentUser, 'form', model, schema);

        return schema;
    }

    async getListSchema(currentUser: TokenPayload, model: string, fresh = false): Promise<MobileListSchema> {
        if (!fresh) {
            const cachedSchema = await this.schemaCache.get<MobileListSchema>(currentUser, 'list', model);
            if (cachedSchema) {
                return cachedSchema;
            }
        }

        const session = await this.sessionStore.getOrThrow(currentUser.sessionHandle);
        const adapter = this.adapterFactory.getAdapter(currentUser.version);
        const schema = await adapter.getListSchema(session, model);
        await this.schemaCache.set(currentUser, 'list', model, schema);

        return schema;
    }
}