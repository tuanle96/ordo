import { Injectable, Logger } from '@nestjs/common';

import type { TokenPayload } from '@app/shared';

import type { InstalledModulesResponse } from '@app/modules/module/module.types';

import { AdapterFactoryService } from '@app/odoo/adapters/adapter-factory.service';
import { OdooSessionStoreService } from '@app/odoo/session/odoo-session-store.service';

const KNOWN_MODULES = ['contacts', 'crm', 'sale'];

@Injectable()
export class ModuleService {
    private readonly logger = new Logger(ModuleService.name);

    constructor(
        private readonly adapterFactory: AdapterFactoryService,
        private readonly sessionStore: OdooSessionStoreService,
    ) { }

    async getInstalledModules(currentUser: TokenPayload): Promise<InstalledModulesResponse> {
        const session = await this.sessionStore.getOrThrow(currentUser.sessionHandle);
        const adapter = this.adapterFactory.getAdapter(currentUser.version);

        const modules = await adapter.getInstalledModules(session, KNOWN_MODULES);

        this.logger.log({
            event: 'installed_modules_fetched',
            count: modules.length,
            names: modules.map((m) => m.name),
        });

        return { modules };
    }
}
