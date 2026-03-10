import { OdooV17Adapter } from '@app/odoo/adapters/odoo-v17.adapter';

describe('OdooV17Adapter getInstalledModules', () => {
    it('returns installed modules matching the requested technical names', async () => {
        const odooRpcService = {
            callKwWithSession: jest.fn().mockResolvedValue([
                { name: 'crm', shortdesc: 'CRM' },
                { name: 'sale', shortdesc: 'Sales' },
            ]),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never);

        await expect(adapter.getInstalledModules(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never,
            ['contacts', 'crm', 'sale'],
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
                    ['name', 'in', ['contacts', 'crm', 'sale']],
                    ['state', '=', 'installed'],
                ],
                fields: ['name', 'shortdesc'],
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
            ['crm', 'sale'],
        )).resolves.toEqual([]);
    });
});
