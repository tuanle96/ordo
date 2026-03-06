import { Injectable } from '@nestjs/common';

import type { MobileFormSchema, TokenPayload } from '@ordo/shared';

import { AdapterFactoryService } from '../../odoo/adapters/adapter-factory.service';
import { OdooSessionStoreService } from '../../odoo/session/odoo-session-store.service';

@Injectable()
export class SchemaService {
    constructor(
        private readonly adapterFactory: AdapterFactoryService,
        private readonly sessionStore: OdooSessionStoreService,
    ) { }

    async getFormSchema(currentUser: TokenPayload, model: string): Promise<MobileFormSchema> {
        const session = this.sessionStore.getOrThrow(currentUser.sessionHandle);
        const adapter = this.adapterFactory.getAdapter(currentUser.version);
        return adapter.getFormSchema(session, model);
    }
}