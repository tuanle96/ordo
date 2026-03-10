import type { TokenPayload } from '@app/shared';

import { ModuleService } from '@app/modules/module/module.service';

describe('ModuleService', () => {
    it('combines installed modules and browse menu tree from adapter discovery', async () => {
        const session = { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' };
        const adapter = {
            isModelAvailable: jest.fn().mockResolvedValue(true),
            getInstalledModules: jest.fn().mockResolvedValue([
                { name: 'crm', displayName: 'CRM' },
            ]),
            getBrowseMenuTree: jest.fn().mockResolvedValue([
                {
                    id: 10,
                    name: 'CRM',
                    kind: 'app',
                    model: 'crm.lead',
                    children: [
                        { id: 11, name: 'Leads', kind: 'leaf', model: 'crm.lead', children: [] },
                    ],
                },
            ]),
        };
        const adapterFactory = {
            getAdapter: jest.fn().mockReturnValue(adapter),
        };
        const sessionStore = {
            getOrThrow: jest.fn().mockResolvedValue(session),
        };
        const service = new ModuleService(adapterFactory as never, sessionStore as never);

        await expect(service.getInstalledModules({
            sessionHandle: 'session-handle',
            version: '17',
        } as TokenPayload)).resolves.toEqual({
            modules: [{ name: 'crm', displayName: 'CRM' }],
            browseMenuTree: [
                {
                    id: 10,
                    name: 'CRM',
                    kind: 'app',
                    model: 'crm.lead',
                    children: [
                        { id: 11, name: 'Leads', kind: 'leaf', model: 'crm.lead', children: [] },
                    ],
                },
            ],
        });

        expect(sessionStore.getOrThrow).toHaveBeenCalledWith('session-handle');
        expect(adapterFactory.getAdapter).toHaveBeenCalledWith('17');
        expect(adapter.getInstalledModules).toHaveBeenCalledWith(session);
        expect(adapter.getBrowseMenuTree).toHaveBeenCalledWith(session);
        expect(adapter.isModelAvailable).toHaveBeenCalledWith(session, 'crm.lead');
    });

    it('prunes browse nodes for models proven unavailable while preserving surviving descendants', async () => {
        const session = { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' };
        const adapter = {
            isModelAvailable: jest.fn().mockImplementation(async (_session, model: string) => model !== 'crm.lead'),
            getInstalledModules: jest.fn().mockResolvedValue([
                { name: 'crm', displayName: 'CRM' },
                { name: 'project', displayName: 'Project' },
            ]),
            getBrowseMenuTree: jest.fn().mockResolvedValue([
                {
                    id: 10,
                    name: 'CRM',
                    kind: 'app',
                    model: 'crm.lead',
                    children: [
                        { id: 11, name: 'Leads', kind: 'leaf', model: 'crm.lead', children: [] },
                        { id: 12, name: 'Tasks', kind: 'leaf', model: 'project.task', children: [] },
                    ],
                },
            ]),
        };
        const adapterFactory = {
            getAdapter: jest.fn().mockReturnValue(adapter),
        };
        const sessionStore = {
            getOrThrow: jest.fn().mockResolvedValue(session),
        };
        const service = new ModuleService(adapterFactory as never, sessionStore as never);

        await expect(service.getInstalledModules({
            sessionHandle: 'session-handle',
            version: '17',
        } as TokenPayload)).resolves.toEqual({
            modules: [
                { name: 'crm', displayName: 'CRM' },
                { name: 'project', displayName: 'Project' },
            ],
            browseMenuTree: [
                {
                    id: 10,
                    name: 'CRM',
                    kind: 'app',
                    model: 'project.task',
                    children: [
                        { id: 12, name: 'Tasks', kind: 'leaf', model: 'project.task', children: [] },
                    ],
                },
            ],
        });
    });

    it('keeps browse nodes when capability probes fail for unknown reasons', async () => {
        const session = { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' };
        const adapter = {
            isModelAvailable: jest.fn().mockRejectedValue(new Error('timeout')),
            getInstalledModules: jest.fn().mockResolvedValue([]),
            getBrowseMenuTree: jest.fn().mockResolvedValue([
                { id: 10, name: 'Contacts', kind: 'app', model: 'res.partner', children: [] },
            ]),
        };
        const adapterFactory = {
            getAdapter: jest.fn().mockReturnValue(adapter),
        };
        const sessionStore = {
            getOrThrow: jest.fn().mockResolvedValue(session),
        };
        const service = new ModuleService(adapterFactory as never, sessionStore as never);

        await expect(service.getInstalledModules({
            sessionHandle: 'session-handle',
            version: '17',
        } as TokenPayload)).resolves.toEqual({
            modules: [],
            browseMenuTree: [
                { id: 10, name: 'Contacts', kind: 'app', model: 'res.partner', children: [] },
            ],
        });
    });
});