import { Injectable, Logger } from '@nestjs/common';

import type { TokenPayload } from '@app/shared';

import type { InstalledModulesResponse } from '@app/modules/module/module.types';

import { AdapterFactoryService } from '@app/odoo/adapters/adapter-factory.service';
import type { OdooAdapter } from '@app/odoo/adapters/odoo-adapter.interface';
import type { OdooSessionContext } from '@app/odoo/session/odoo-session.types';
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

        const [modules, rawBrowseMenuTree] = await Promise.all([
            adapter.getInstalledModules(session),
            adapter.getBrowseMenuTree(session),
        ]);
        const browseMenuTree = await this.pruneUnavailableBrowseMenuTree(adapter, session, rawBrowseMenuTree);

        const rawBrowseModels = this.collectBrowseModels(rawBrowseMenuTree);
        const browseModels = this.collectBrowseModels(browseMenuTree);

        this.logger.log({
            event: 'installed_modules_fetched',
            moduleCount: modules.length,
            browseMenuRootCount: browseMenuTree.length,
            browseModelCount: browseModels.length,
            moduleNames: modules.map((module) => module.name),
            browseModelNames: browseModels,
            prunedBrowseModelNames: rawBrowseModels.filter((model) => !browseModels.includes(model)),
        });

        return { modules, browseMenuTree };
    }

    private async pruneUnavailableBrowseMenuTree(
        adapter: OdooAdapter,
        session: OdooSessionContext,
        browseMenuTree: InstalledModulesResponse['browseMenuTree'],
    ): Promise<InstalledModulesResponse['browseMenuTree']> {
        const availabilityByModel = await this.resolveBrowseModelAvailability(adapter, session, browseMenuTree);

        return browseMenuTree
            .map((node) => this.pruneBrowseMenuNode(node, availabilityByModel))
            .filter((node): node is NonNullable<typeof node> => node !== undefined);
    }

    private async resolveBrowseModelAvailability(
        adapter: OdooAdapter,
        session: OdooSessionContext,
        browseMenuTree: InstalledModulesResponse['browseMenuTree'],
    ): Promise<Map<string, boolean>> {
        const uniqueModels = this.collectBrowseModels(browseMenuTree);
        const availabilityEntries = await Promise.all(uniqueModels.map(async (model) => {
            try {
                return [model, await adapter.isModelAvailable(session, model)] as const;
            } catch (error) {
                this.logger.warn({
                    event: 'browse_model_probe_failed',
                    model,
                    error: error instanceof Error ? error.message : 'unknown error',
                });

                return [model, true] as const;
            }
        }));

        return new Map(availabilityEntries);
    }

    private pruneBrowseMenuNode(
        node: InstalledModulesResponse['browseMenuTree'][number],
        availabilityByModel: Map<string, boolean>,
    ): InstalledModulesResponse['browseMenuTree'][number] | undefined {
        const children = node.children
            .map((childNode) => this.pruneBrowseMenuNode(childNode, availabilityByModel))
            .filter((childNode): childNode is NonNullable<typeof childNode> => childNode !== undefined);

        const isModelAvailable = !node.model || availabilityByModel.get(node.model) !== false;
        if (!isModelAvailable && children.length === 0) {
            return undefined;
        }

        return {
            ...node,
            model: !isModelAvailable
                ? node.kind === 'app'
                    ? this.findFirstBrowseableModel(children)
                    : undefined
                : node.model,
            children,
        };
    }

    private findFirstBrowseableModel(nodes: InstalledModulesResponse['browseMenuTree']): string | undefined {
        for (const node of nodes) {
            if (node.model) {
                return node.model;
            }

            const descendantModel = this.findFirstBrowseableModel(node.children);
            if (descendantModel) {
                return descendantModel;
            }
        }

        return undefined;
    }

    private collectBrowseModels(browseMenuTree: InstalledModulesResponse['browseMenuTree']): string[] {
        const occurrences = browseMenuTree.flatMap((node) => {
            const descendants = this.collectBrowseModels(node.children);
            return node.model ? [node.model, ...descendants] : descendants;
        });

        return Array.from(new Set(occurrences));
    }
}
