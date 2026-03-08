import { BadGatewayException, BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
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
            email: undefined,
            lang: 'en_US',
            tz: undefined,
            groups: [4],
        });
    });

    it('maps AccessError upstream failures to forbidden responses', () => {
        const configService = {
            get: jest.fn().mockReturnValue(15000),
        } as unknown as ConfigService;
        const service = new OdooRpcService(configService);

        const error = (service as any).mapOdooError({
            message: 'Odoo Server Error',
            data: {
                name: 'odoo.exceptions.AccessError',
                message: 'You are not allowed to access this document.',
            },
        });

        expect(error).toBeInstanceOf(ForbiddenException);
        expect(error.message).toBe('You do not have permission to access this record or perform this action.');
    });

    it('maps MissingError upstream failures to not found responses', () => {
        const configService = {
            get: jest.fn().mockReturnValue(15000),
        } as unknown as ConfigService;
        const service = new OdooRpcService(configService);

        const error = (service as any).mapOdooError({
            message: 'Odoo Server Error',
            data: {
                name: 'odoo.exceptions.MissingError',
                message: 'Record does not exist or has been deleted.',
            },
        });

        expect(error).toBeInstanceOf(NotFoundException);
        expect(error.message).toBe('The requested record was not found or is no longer available.');
    });

    it('maps ValidationError upstream failures to bad request responses', () => {
        const configService = {
            get: jest.fn().mockReturnValue(15000),
        } as unknown as ConfigService;
        const service = new OdooRpcService(configService);

        const error = (service as any).mapOdooError({
            message: 'Odoo Server Error',
            data: {
                name: 'odoo.exceptions.ValidationError',
                message: 'Name is required.',
            },
        });

        expect(error).toBeInstanceOf(BadRequestException);
        expect(error.message).toBe('Name is required.');
    });
});