import {
    BadGatewayException,
    BadRequestException,
    ForbiddenException,
    NotFoundException,
    ServiceUnavailableException,
} from '@nestjs/common';
import type { ConfigService } from '@nestjs/config';

import { OdooRpcService } from '@app/odoo/rpc/odoo-rpc.service';

describe('OdooRpcService', () => {
    afterEach(() => {
        jest.restoreAllMocks();
    });

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

    it('maps uninitialized database auth failures to service unavailable responses', () => {
        const configService = {
            get: jest.fn().mockReturnValue(15000),
        } as unknown as ConfigService;
        const service = new OdooRpcService(configService);

        const error = (service as any).mapOdooError({
            message: 'Odoo Server Error',
            data: {
                name: 'builtins.KeyError',
                message: 'res.users',
                debug: 'Traceback...\nKeyError: \'res.users\'\n',
            },
        });

        expect(error).toBeInstanceOf(ServiceUnavailableException);
        expect(error.message).toBe(
            'The selected Odoo database is not initialized yet. Finish Odoo database setup, then try logging in again.',
        );
    });

    it('maps missing ir_module_module upstream failures to service unavailable responses', () => {
        const configService = {
            get: jest.fn().mockReturnValue(15000),
        } as unknown as ConfigService;
        const service = new OdooRpcService(configService);

        const error = (service as any).mapOdooError({
            message: 'Odoo Server Error',
            data: {
                name: 'psycopg2.errors.UndefinedTable',
                message: 'Database bootstrap failed.',
                debug: 'Traceback...\npsycopg2.errors.UndefinedTable: relation "ir_module_module" does not exist\n',
            },
        });

        expect(error).toBeInstanceOf(ServiceUnavailableException);
        expect(error.message).toBe(
            'The selected Odoo database is not initialized yet. Finish Odoo database setup, then try logging in again.',
        );
    });

    it('maps undefined table polling upstream failures to service unavailable responses', () => {
        const configService = {
            get: jest.fn().mockReturnValue(15000),
        } as unknown as ConfigService;
        const service = new OdooRpcService(configService);

        const error = (service as any).mapOdooError({
            message: 'Odoo Server Error',
            data: {
                name: 'odoo.sql_db.Error',
                message: 'Tried to poll an undefined table on database odoo17.',
                debug: 'Traceback...\nTried to poll an undefined table on database odoo17.\n',
            },
        });

        expect(error).toBeInstanceOf(ServiceUnavailableException);
        expect(error.message).toBe(
            'The selected Odoo database is not initialized yet. Finish Odoo database setup, then try logging in again.',
        );
    });

    it('maps missing model KeyError upstream failures to not found responses', () => {
        const configService = {
            get: jest.fn().mockReturnValue(15000),
        } as unknown as ConfigService;
        const service = new OdooRpcService(configService);

        const error = (service as any).mapOdooError({
            message: 'Odoo Server Error',
            data: {
                name: 'builtins.KeyError',
                message: 'crm.lead',
                debug: 'Traceback...\nKeyError: \'crm.lead\'\n',
            },
        });

        expect(error).toBeInstanceOf(NotFoundException);
        expect(error.message).toBe('The requested Odoo model is not available on this server or database.');
    });

    it('logs structured context for call_kw JSON-RPC failures while preserving the outward exception', async () => {
        const configService = {
            get: jest.fn().mockReturnValue(15000),
        } as unknown as ConfigService;
        const service = new OdooRpcService(configService);
        const loggerErrorSpy = jest.spyOn((service as any).logger, 'error').mockImplementation();
        const upstreamDebug = `Traceback...\n${'x'.repeat(120)}\nsession_id=abc123 password=super-secret api_key=api-123 access_token=tok-456 client_secret=sec-789\n${'y'.repeat(520)}`;

        const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValue({
            ok: true,
            json: async () => ({
                jsonrpc: '2.0',
                id: 1,
                error: {
                    code: 200,
                    message: 'Odoo Server Error',
                    data: {
                        name: 'builtins.KeyError',
                        message: 'crm.lead',
                        debug: upstreamDebug,
                    },
                },
            }),
        } as Response);

        await expect(service.callKwWithSession({
            session: { odooUrl: 'http://127.0.0.1:38421', cookieHeader: 'session_id=abc123' },
            model: 'crm.lead',
            method: 'fields_get',
            kwargs: { attributes: ['string'] },
        })).rejects.toThrow(NotFoundException);

        expect(fetchSpy).toHaveBeenCalledTimes(1);
        expect(loggerErrorSpy).toHaveBeenCalledWith(expect.objectContaining({
            event: 'odoo_upstream_rpc_error',
            path: '/web/dataset/call_kw',
            model: 'crm.lead',
            method: 'fields_get',
            upstreamErrorName: 'builtins.KeyError',
            upstreamMessage: 'crm.lead',
            upstreamDebugSnippet: expect.any(String),
        }));

        const [logPayload] = loggerErrorSpy.mock.calls[0] as [Record<string, string>];
        expect(logPayload.upstreamDebugSnippet.length).toBeLessThanOrEqual(500);
        expect(logPayload.upstreamDebugSnippet).toContain('session_id=[Redacted]');
        expect(logPayload.upstreamDebugSnippet).toContain('password=[Redacted]');
        expect(logPayload.upstreamDebugSnippet).toContain('api_key=[Redacted]');
        expect(logPayload.upstreamDebugSnippet).toContain('access_token=[Redacted]');
        expect(logPayload.upstreamDebugSnippet).toContain('client_secret=[Redacted]');
        expect(logPayload.upstreamDebugSnippet).not.toContain('abc123');
        expect(logPayload.upstreamDebugSnippet).not.toContain('super-secret');
        expect(logPayload.upstreamDebugSnippet).not.toContain('api-123');
        expect(logPayload.upstreamDebugSnippet).not.toContain('tok-456');
        expect(logPayload.upstreamDebugSnippet).not.toContain('sec-789');
    });
});