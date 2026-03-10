import { OdooV17Adapter } from '@app/odoo/adapters/odoo-v17.adapter';

describe('OdooV17Adapter getInstalledModules', () => {
    it('returns installed application modules without a hardcoded whitelist', async () => {
        const odooRpcService = {
            callKwWithSession: jest.fn().mockResolvedValue([
                { name: 'crm', shortdesc: 'CRM' },
                { name: 'sale', shortdesc: 'Sales' },
            ]),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never);

        await expect(adapter.getInstalledModules(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never,
        )).resolves.toEqual([
            { name: 'crm', displayName: 'CRM' },
            { name: 'sale', displayName: 'Sales' },
        ]);

        expect(odooRpcService.callKwWithSession).toHaveBeenCalledWith({
            session: { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            model: 'ir.module.module',
            method: 'search_read',
            kwargs: {
                domain: [
                    ['state', '=', 'installed'],
                    ['application', '=', true],
                ],
                fields: ['name', 'shortdesc'],
                order: 'shortdesc asc, name asc',
            },
        });
    });

    it('returns an empty array when no modules are installed', async () => {
        const odooRpcService = {
            callKwWithSession: jest.fn().mockResolvedValue([]),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never);

        await expect(adapter.getInstalledModules(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never,
        )).resolves.toEqual([]);
    });
});

describe('OdooV17Adapter getBrowseModels', () => {
    it('returns unique browseable models discovered from active menu-backed window actions', async () => {
        const odooRpcService = {
            callKwWithSession: jest.fn()
                .mockResolvedValueOnce([
                    { name: 'Contacts', action: 'ir.actions.act_window,11' },
                    { name: 'Leads', action: 'ir.actions.act_window,12' },
                    { name: 'Duplicate Leads', action: 'ir.actions.act_window,13' },
                    { name: 'Popup Wizard', action: 'ir.actions.act_window,14' },
                    { name: 'Server Action', action: 'ir.actions.server,15' },
                ])
                .mockResolvedValueOnce([
                    { id: 11, name: 'Contacts', res_model: 'res.partner', view_mode: 'tree,form', target: 'current' },
                    { id: 12, name: 'Leads', res_model: 'crm.lead', view_mode: 'kanban,form', target: 'current' },
                    { id: 13, name: 'Lead Form', res_model: 'crm.lead', view_mode: 'tree,form', target: 'current' },
                    { id: 14, name: 'Wizard', res_model: 'crm.merge.opportunity', view_mode: 'form', target: 'new' },
                ]),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never);

        await expect(adapter.getBrowseModels(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never,
        )).resolves.toEqual([
            { model: 'res.partner', title: 'Contacts' },
            { model: 'crm.lead', title: 'Leads' },
        ]);

        expect(odooRpcService.callKwWithSession).toHaveBeenNthCalledWith(1, {
            session: { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            model: 'ir.ui.menu',
            method: 'search_read',
            kwargs: {
                domain: [
                    ['action', '!=', false],
                    ['active', '=', true],
                ],
                fields: ['name', 'action'],
                order: 'sequence asc, id asc',
            },
        });
        expect(odooRpcService.callKwWithSession).toHaveBeenNthCalledWith(2, {
            session: { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            model: 'ir.actions.act_window',
            method: 'read',
            args: [[11, 12, 13, 14]],
            kwargs: {
                fields: ['id', 'name', 'res_model', 'view_mode', 'target'],
            },
        });
    });

    it('returns an empty array when no browseable window actions are discovered', async () => {
        const odooRpcService = {
            callKwWithSession: jest.fn().mockResolvedValue([]),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never);

        await expect(adapter.getBrowseModels(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never,
        )).resolves.toEqual([]);
    });
});
