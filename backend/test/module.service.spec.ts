import type { TokenPayload } from '@app/shared';

import { ModuleService } from '@app/modules/module/module.service';

describe('ModuleService', () => {
    it('combines installed modules and browse models from adapter discovery', async () => {
        const session = { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' };
        const adapter = {
            getInstalledModules: jest.fn().mockResolvedValue([
                { name: 'crm', displayName: 'CRM' },
            ]),
            getBrowseModels: jest.fn().mockResolvedValue([
                { model: 'crm.lead', title: 'Leads' },
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
            browseModels: [{ model: 'crm.lead', title: 'Leads' }],
        });

        expect(sessionStore.getOrThrow).toHaveBeenCalledWith('session-handle');
        expect(adapterFactory.getAdapter).toHaveBeenCalledWith('17');
        expect(adapter.getInstalledModules).toHaveBeenCalledWith(session);
        expect(adapter.getBrowseModels).toHaveBeenCalledWith(session);
    });
});