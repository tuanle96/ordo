import { BadGatewayException } from '@nestjs/common';

import { OdooV17Adapter } from '../src/odoo/adapters/odoo-v17.adapter';

describe('OdooV17Adapter onchange', () => {
    it('uses fields spec + onchange RPC and normalizes the result', async () => {
        const odooRpcService = {
            getFieldsSpecWithSession: jest.fn().mockResolvedValue({ country_id: {}, company_id: {} }),
            runModelOnchangeWithSession: jest.fn().mockResolvedValue({
                value: { name: 'Acme' },
                warning: { title: 'Heads up', message: 'Country changed.', type: 'warning' },
                domain: { company_id: [['country_id', '=', 21]] },
            }),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never);

        await expect(adapter.runOnchange({ cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never, 'res.partner', {
            values: { country_id: 21 },
            triggerField: 'country_id',
            recordId: 3,
        })).resolves.toEqual({
            values: { name: 'Acme' },
            warnings: [{ title: 'Heads up', message: 'Country changed.', type: 'warning' }],
            domains: { company_id: [['country_id', '=', 21]] },
        });

        expect(odooRpcService.getFieldsSpecWithSession).toHaveBeenCalledWith(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            'res.partner',
        );
        expect(odooRpcService.runModelOnchangeWithSession).toHaveBeenCalledWith(
            { cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' },
            'res.partner',
            { country_id: 21 },
            'country_id',
            { country_id: {}, company_id: {} },
            3,
        );
    });

    it('fails closed on unsupported warning payloads', async () => {
        const odooRpcService = {
            getFieldsSpecWithSession: jest.fn().mockResolvedValue({ country_id: {} }),
            runModelOnchangeWithSession: jest.fn().mockResolvedValue({
                value: { name: 'Acme' },
                warning: 'bad-warning-shape',
            }),
        };
        const adapter = new OdooV17Adapter(odooRpcService as never, {} as never);

        await expect(adapter.runOnchange({ cookieHeader: 'session_id=abc123', odooUrl: 'http://example.com' } as never, 'res.partner', {
            values: { country_id: 21 },
            triggerField: 'country_id',
        })).rejects.toBeInstanceOf(BadGatewayException);
    });
});