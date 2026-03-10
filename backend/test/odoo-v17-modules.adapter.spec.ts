import { NotFoundException } from '@nestjs/common';

import { OdooV17Adapter } from '@app/odoo/adapters/odoo-v17.adapter';

describe('OdooV17Adapter getInstalledModules', () => {
    it('returns installed application modules without a hardcoded whitelist', async () => {
        const odooRpcService = {
            callKwWithSession: jest.fn().mockResolvedValue([
                { name: 'crm', shortdesc: 'CRM' },
                { name: 'sale', shortdesc: 'Sales' },
            ]),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never, {} as never);

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
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never, {} as never);

        await expect(adapter.getInstalledModules(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never,
        )).resolves.toEqual([]);
    });
});

describe('OdooV17Adapter isModelAvailable', () => {
    it('returns false when the model is explicitly unavailable', async () => {
        const odooRpcService = {
            callKwWithSession: jest.fn().mockRejectedValue(new NotFoundException('missing model')),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never, {} as never);

        await expect(adapter.isModelAvailable(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never,
            'crm.lead',
        )).resolves.toBe(false);
    });

    it('rethrows unexpected probe failures', async () => {
        const odooRpcService = {
            callKwWithSession: jest.fn().mockRejectedValue(new Error('timeout')),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never, {} as never);

        await expect(adapter.isModelAvailable(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never,
            'crm.lead',
        )).rejects.toThrow('timeout');
    });
});

describe('OdooV17Adapter getBrowseMenuTree', () => {
    it('returns a pruned browse menu tree with app fallback model resolution', async () => {
        const odooRpcService = {
            callKwWithSession: jest.fn()
                .mockResolvedValueOnce([
                    { id: 10, name: 'Contacts', parent_id: false, action: false },
                    { id: 11, name: 'Contacts', parent_id: [10, 'Contacts'], action: 'ir.actions.act_window,21' },
                    { id: 20, name: 'CRM', parent_id: false, action: false },
                    { id: 21, name: 'Sales', parent_id: [20, 'CRM'], action: false },
                    { id: 22, name: 'Leads', parent_id: [21, 'Sales'], action: 'ir.actions.act_window,22' },
                    { id: 23, name: 'Popup Wizard', parent_id: [21, 'Sales'], action: 'ir.actions.act_window,23' },
                    { id: 24, name: 'Server Action', parent_id: [20, 'CRM'], action: 'ir.actions.server,24' },
                    { id: 30, name: 'Empty App', parent_id: false, action: false },
                ])
                .mockResolvedValueOnce([
                    { id: 21, name: 'Contacts', res_model: 'res.partner', view_mode: 'tree,form', target: 'current' },
                    { id: 22, name: 'Leads', res_model: 'crm.lead', view_mode: 'kanban,form', target: 'current' },
                    { id: 23, name: 'Wizard', res_model: 'crm.merge.opportunity', view_mode: 'form', target: 'new' },
                ]),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never, {} as never);

        await expect(adapter.getBrowseMenuTree(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never,
        )).resolves.toEqual([
            {
                id: 10,
                name: 'Contacts',
                kind: 'app',
                model: 'res.partner',
                children: [
                    { id: 11, name: 'Contacts', kind: 'leaf', model: 'res.partner', preferredViewMode: 'list', children: [] },
                ],
            },
            {
                id: 20,
                name: 'CRM',
                kind: 'app',
                model: 'crm.lead',
                children: [
                    {
                        id: 21,
                        name: 'Sales',
                        kind: 'category',
                        children: [
                            { id: 22, name: 'Leads', kind: 'leaf', model: 'crm.lead', preferredViewMode: 'kanban', children: [] },
                        ],
                    },
                ],
            },
        ]);

        expect(odooRpcService.callKwWithSession).toHaveBeenNthCalledWith(1, {
            session: { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            model: 'ir.ui.menu',
            method: 'search_read',
            kwargs: {
                domain: [['active', '=', true]],
                fields: ['id', 'name', 'parent_id', 'action'],
                order: 'sequence asc, id asc',
            },
        });
        expect(odooRpcService.callKwWithSession).toHaveBeenNthCalledWith(2, {
            session: { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            model: 'ir.actions.act_window',
            method: 'read',
            args: [[21, 22, 23]],
            kwargs: {
                fields: ['id', 'name', 'res_model', 'view_mode', 'target'],
            },
        });
    });

    it('returns an empty array when no browseable window actions are discovered', async () => {
        const odooRpcService = {
            callKwWithSession: jest.fn().mockResolvedValue([]),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never, {} as never);

        await expect(adapter.getBrowseMenuTree(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never,
        )).resolves.toEqual([]);
    });
});
