import { BadGatewayException } from '@nestjs/common';

import { OdooV17Adapter } from '@app/odoo/adapters/odoo-v17.adapter';

describe('OdooV17Adapter onchange', () => {
    it('loads narrow default values through default_get', async () => {
        const odooRpcService = {
            callKwWithSession: jest.fn().mockResolvedValue({ name: 'Draft Customer', country_id: 21 }),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never);

        await expect(adapter.getDefaultValues(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never,
            'res.partner',
            ['name', 'country_id'],
        )).resolves.toEqual({ name: 'Draft Customer', country_id: 21 });

        expect(odooRpcService.callKwWithSession).toHaveBeenCalledWith({
            session: { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            model: 'res.partner',
            method: 'default_get',
            args: [['name', 'country_id']],
        });
    });

    it('uses request-scoped fields spec for onchange RPC and normalizes the result', async () => {
        const odooRpcService = {
            runModelOnchangeWithSession: jest.fn().mockResolvedValue({
                value: { name: 'Acme' },
                warning: { title: 'Heads up', message: 'Country changed.', type: 'warning' },
                domain: { company_id: [['country_id', '=', 21]] },
            }),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never);

        await expect(adapter.runOnchange({ cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never, 'res.partner', {
            values: { country_id: 21 },
            triggerField: 'country_id',
            recordId: 3,
            fields: ['name', 'company_id'],
        })).resolves.toEqual({
            values: { name: 'Acme' },
            warnings: [{ title: 'Heads up', message: 'Country changed.', type: 'warning' }],
            domains: { company_id: [['country_id', '=', 21]] },
        });

        expect(odooRpcService.runModelOnchangeWithSession).toHaveBeenCalledWith(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            'res.partner',
            { country_id: 21 },
            'country_id',
            { name: {}, company_id: {}, country_id: {} },
            3,
        );
    });

    it('fails closed on unsupported warning payloads', async () => {
        const odooRpcService = {
            runModelOnchangeWithSession: jest.fn().mockResolvedValue({
                value: { name: 'Acme' },
                warning: 'bad-warning-shape',
            }),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never);

        await expect(adapter.runOnchange({ cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never, 'res.partner', {
            values: { country_id: 21 },
            triggerField: 'country_id',
        })).rejects.toBeInstanceOf(BadGatewayException);
    });

    it('fails closed on unsupported value payloads', async () => {
        const odooRpcService = {
            runModelOnchangeWithSession: jest.fn().mockResolvedValue({
                value: ['bad-value-shape'],
            }),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never);

        await expect(adapter.runOnchange({ cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never, 'res.partner', {
            values: { country_id: 21 },
            triggerField: 'country_id',
        })).rejects.toBeInstanceOf(BadGatewayException);
    });

    it('fails closed on unsupported domain payloads', async () => {
        const odooRpcService = {
            runModelOnchangeWithSession: jest.fn().mockResolvedValue({
                value: { name: 'Acme' },
                domain: 'bad-domain-shape',
            }),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never);

        await expect(adapter.runOnchange({ cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never, 'res.partner', {
            values: { country_id: 21 },
            triggerField: 'country_id',
        })).rejects.toBeInstanceOf(BadGatewayException);
    });

    it('loads list schema from tree and search views', async () => {
        const odooRpcService = {
            callKwWithSession: jest
                .fn()
                .mockResolvedValueOnce({
                    name: { type: 'char', string: 'Name' },
                    email: { type: 'char', string: 'Email' },
                })
                .mockResolvedValueOnce({ arch: '<tree string="Partners"><field name="name" /><field name="email" optional="hide" /></tree>' })
                .mockResolvedValueOnce({ arch: '<search><field name="name" /><filter name="companies" string="Companies" domain="[(\'is_company\',\'=\',True)]" /></search>' }),
        };
        const listSchemaBuilder = {
            build: jest.fn().mockReturnValue({
                model: 'res.partner',
                title: 'Partners',
                columns: [{ name: 'name', type: 'char', label: 'Name' }],
                search: { fields: [], filters: [], groupBy: [] },
            }),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, listSchemaBuilder as never);

        await expect(adapter.getListSchema({ cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never, 'res.partner')).resolves.toEqual({
            model: 'res.partner',
            title: 'Partners',
            columns: [{ name: 'name', type: 'char', label: 'Name' }],
            search: { fields: [], filters: [], groupBy: [] },
        });

        expect(odooRpcService.callKwWithSession).toHaveBeenNthCalledWith(1, {
            session: { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            model: 'res.partner',
            method: 'fields_get',
            kwargs: { attributes: ['string', 'type', 'relation', 'selection'] },
        });
        expect(odooRpcService.callKwWithSession).toHaveBeenNthCalledWith(2, {
            session: { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            model: 'res.partner',
            method: 'get_view',
            kwargs: { view_type: 'tree' },
        });
        expect(odooRpcService.callKwWithSession).toHaveBeenNthCalledWith(3, {
            session: { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            model: 'res.partner',
            method: 'get_view',
            kwargs: { view_type: 'search' },
        });
        expect(listSchemaBuilder.build).toHaveBeenCalledWith(
            'res.partner',
            '<tree string="Partners"><field name="name" /><field name="email" optional="hide" /></tree>',
            '<search><field name="name" /><filter name="companies" string="Companies" domain="[(\'is_company\',\'=\',True)]" /></search>',
            {
                name: { type: 'char', string: 'Name' },
                email: { type: 'char', string: 'Email' },
            },
        );
    });

    it('returns search_read items together with search_count total', async () => {
        const odooRpcService = {
            callKwWithSession: jest
                .fn()
                .mockResolvedValueOnce([{ id: 1, name: 'Azure Interior' }])
                .mockResolvedValueOnce(42),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never);

        await expect(adapter.searchRecords(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never,
            'res.partner',
            { domain: [['is_company', '=', true]], fields: ['id', 'name'], limit: 30, offset: 0, order: 'name asc' },
        )).resolves.toEqual({
            items: [{ id: 1, name: 'Azure Interior' }],
            limit: 30,
            offset: 0,
            total: 42,
        });

        expect(odooRpcService.callKwWithSession).toHaveBeenNthCalledWith(1, {
            session: { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            model: 'res.partner',
            method: 'search_read',
            kwargs: {
                domain: [['is_company', '=', true]],
                fields: ['id', 'name'],
                limit: 30,
                offset: 0,
                order: 'name asc',
            },
        });
        expect(odooRpcService.callKwWithSession).toHaveBeenNthCalledWith(2, {
            session: { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            model: 'res.partner',
            method: 'search_count',
            args: [[['is_company', '=', true]]],
        });
    });

    it('loads chatter details including available activity types', async () => {
        const odooRpcService = {
            callKwWithSession: jest
                .fn()
                .mockResolvedValueOnce([{ partner_id: [7, 'Administrator'] }])
                .mockResolvedValueOnce([{ id: 15, partner_id: [7, 'Administrator'], name: 'Administrator', email: 'admin@example.com', is_active: true }])
                .mockResolvedValueOnce(1)
                .mockResolvedValueOnce([{ id: 15, partner_id: [7, 'Administrator'], name: 'Administrator', email: 'admin@example.com', is_active: true }])
                .mockResolvedValueOnce([{ id: 44, activity_type_id: [3, 'To Do'], summary: 'Follow up', note: '<p>Call back</p>', date_deadline: '2026-03-10', state: 'planned', can_write: true, user_id: [2, 'Administrator'] }])
                .mockResolvedValueOnce([{ id: 3, name: 'To Do', summary: 'Follow up', icon: 'fa-tasks', default_note: '<p>Default</p>' }]),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never);

        await expect(adapter.getChatterDetails({ cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com', uid: 2 } as never, 'res.partner', 3)).resolves.toEqual({
            followers: [{ id: 15, partnerId: 7, name: 'Administrator', email: 'admin@example.com', isActive: true, isSelf: true }],
            followersCount: 1,
            selfFollower: { id: 15, partnerId: 7, name: 'Administrator', email: 'admin@example.com', isActive: true, isSelf: true },
            activities: [{ id: 44, typeId: 3, typeName: 'To Do', summary: 'Follow up', note: '<p>Call back</p>', plainNote: 'Call back', dateDeadline: '2026-03-10', state: 'planned', canWrite: true, assignedUser: { id: 2, name: 'Administrator' } }],
            availableActivityTypes: [{ id: 3, name: 'To Do', summary: 'Follow up', icon: 'fa-tasks', defaultNote: '<p>Default</p>' }],
        });
    });

    it('schedules an activity through the record model and refreshes details', async () => {
        const odooRpcService = {
            callKwWithSession: jest
                .fn()
                .mockResolvedValueOnce([{ id: 5 }])
                .mockResolvedValueOnce(true)
                .mockResolvedValueOnce([{ partner_id: [7, 'Administrator'] }])
                .mockResolvedValueOnce([])
                .mockResolvedValueOnce(0)
                .mockResolvedValueOnce([])
                .mockResolvedValueOnce([])
                .mockResolvedValueOnce([{ id: 5, name: 'To Do', summary: 'Follow up', icon: 'fa-tasks', default_note: false }]),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never, {} as never);

        await expect(adapter.scheduleChatterActivity(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com', uid: 2 } as never,
            'res.partner',
            3,
            5,
            { summary: 'Call customer', note: 'Ask for update', dateDeadline: '2026-03-12' },
        )).resolves.toEqual({
            followers: [],
            followersCount: 0,
            selfFollower: undefined,
            activities: [],
            availableActivityTypes: [{ id: 5, name: 'To Do', summary: 'Follow up', icon: 'fa-tasks', defaultNote: undefined }],
        });

        expect(odooRpcService.callKwWithSession).toHaveBeenNthCalledWith(2, {
            session: { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com', uid: 2 },
            model: 'res.partner',
            method: 'activity_schedule',
            args: [[3]],
            kwargs: {
                activity_type_id: 5,
                user_id: 2,
                automated: false,
                summary: 'Call customer',
                note: 'Ask for update',
                date_deadline: '2026-03-12',
            },
        });
    });
});