import { Injectable, Logger } from '@nestjs/common';

import type { TokenPayload } from '@app/shared';

import type { InstalledModulesResponse } from '@app/modules/module/module.types';

import { AdapterFactoryService } from '@app/odoo/adapters/adapter-factory.service';
import { OdooSessionStoreService } from '@app/odoo/session/odoo-session-store.service';

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

        const [modules, browseModels] = await Promise.all([
            adapter.getInstalledModules(session),
            adapter.getBrowseModels(session),
        ]);

        this.logger.log({
            event: 'installed_modules_fetched',
            moduleCount: modules.length,
            browseModelCount: browseModels.length,
            moduleNames: modules.map((module) => module.name),
            browseModelNames: browseModels.map((browseModel) => browseModel.model),
        });

        return { modules, browseModels };
    }
}
