import { BadGatewayException } from '@nestjs/common';
import type { ConfigService } from '@nestjs/config';

import { OdooRpcService } from '../src/odoo/rpc/odoo-rpc.service';

describe('OdooRpcService', () => {
    it('falls back to group_ids when groups_id is invalid upstream', async () => {
        const configService = {
            get: jest.fn().mockReturnValue(15000),
        } as unknown as ConfigService;
        const service = new OdooRpcService(configService);

        const callKwWithSessionSpy = jest.spyOn(service, 'callKwWithSession')
            .mockRejectedValueOnce(new BadGatewayException('Odoo upstream request failed'))
            .mockResolvedValueOnce([
                {
                    id: 2,
                    name: 'Administrator',
                    email: false,
                    lang: 'en_US',
                    tz: false,
                    group_ids: [4],
                },
            ]);

        const user = await service.readCurrentUserWithSession(
            { odooUrl: 'http://127.0.0.1:38423', cookieHeader: 'session_id=abc123' },
            2,
        );

        expect(callKwWithSessionSpy).toHaveBeenNthCalledWith(1, {
            session: { odooUrl: 'http://127.0.0.1:38423', cookieHeader: 'session_id=abc123' },
            model: 'res.users',
            method: 'read',
            args: [[2]],
            kwargs: { fields: ['id', 'name', 'email', 'lang', 'tz', 'groups_id'] },
        });
        expect(callKwWithSessionSpy).toHaveBeenNthCalledWith(2, {
            session: { odooUrl: 'http://127.0.0.1:38423', cookieHeader: 'session_id=abc123' },
            model: 'res.users',
            method: 'read',
            args: [[2]],
            kwargs: { fields: ['id', 'name', 'email', 'lang', 'tz', 'group_ids'] },
        });
        expect(user).toEqual({
            id: 2,
            name: 'Administrator',
            email: false,
            lang: 'en_US',
            tz: false,
            groups: [4],
        });
    });
});