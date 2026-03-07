import type { ConfigService } from '@nestjs/config';
import type { JwtService } from '@nestjs/jwt';

import { AuthService } from '../src/modules/auth/auth.service';

describe('AuthService', () => {
    it('normalizes falsy optional user fields before issuing tokens and responses', async () => {
        const configService = {
            get: jest.fn((key: string, fallback?: number) => fallback),
            getOrThrow: jest.fn(() => 'test-secret'),
        } as unknown as ConfigService;
        const jwtService = {
            signAsync: jest
                .fn()
                .mockResolvedValueOnce('access-token')
                .mockResolvedValueOnce('refresh-token'),
        } as unknown as JwtService;
        const odooRpcService = {
            detectVersion: jest.fn().mockResolvedValue({ majorVersion: '17' }),
            authenticateSession: jest.fn().mockResolvedValue({
                uid: 2,
                cookieHeader: 'session_id=abc123',
            }),
            readCurrentUserWithSession: jest.fn().mockResolvedValue({
                id: 2,
                name: 'Administrator',
                email: false,
                lang: 'en_US',
                tz: false,
                groups: [1, 2],
            }),
            normalizeBaseUrl: jest.fn().mockReturnValue('http://127.0.0.1:38421'),
        };
        const adapterFactoryService = {
            getAdapter: jest.fn(),
        };
        const sessionStore = {
            create: jest.fn().mockReturnValue({ handle: 'session-handle-123' }),
        };

        const service = new AuthService(
            configService,
            jwtService,
            odooRpcService as never,
            adapterFactoryService as never,
            sessionStore as never,
        );

        const response = await service.login({
            odooUrl: 'http://127.0.0.1:38421',
            db: 'odoo17',
            login: 'admin',
            password: 'admin',
        });

        expect(response).toEqual({
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            expiresIn: 900,
            user: {
                id: 2,
                name: 'Administrator',
                email: undefined,
                lang: 'en_US',
                tz: undefined,
            },
        });
        expect(jwtService.signAsync).toHaveBeenNthCalledWith(
            1,
            expect.objectContaining({
                uid: 2,
                email: undefined,
                tz: undefined,
                sessionHandle: 'session-handle-123',
            }),
            expect.objectContaining({ secret: 'test-secret', expiresIn: 900 }),
        );
        expect(jwtService.signAsync).toHaveBeenNthCalledWith(
            2,
            expect.objectContaining({
                uid: 2,
                email: undefined,
                tz: undefined,
                sessionHandle: 'session-handle-123',
            }),
            expect.objectContaining({ secret: 'test-secret', expiresIn: 604800 }),
        );
    });

    it('refreshes tokens when the refresh token is valid and the session is still active', async () => {
        const configService = {
            get: jest.fn((key: string, fallback?: number) => fallback),
            getOrThrow: jest.fn(() => 'test-secret'),
        } as unknown as ConfigService;
        const jwtService = {
            verifyAsync: jest.fn().mockResolvedValue({
                uid: 2,
                db: 'odoo17',
                odooUrl: 'http://127.0.0.1:38421',
                version: '17',
                lang: 'en_US',
                groups: [1, 2],
                name: 'Administrator',
                email: false,
                tz: false,
                sessionHandle: 'session-handle-123',
            }),
            signAsync: jest
                .fn()
                .mockResolvedValueOnce('new-access-token')
                .mockResolvedValueOnce('new-refresh-token'),
        } as unknown as JwtService;
        const sessionStore = {
            touchOrThrow: jest.fn().mockReturnValue({
                handle: 'session-handle-123',
                odooUrl: 'http://127.0.0.1:38421',
                db: 'odoo17',
                uid: 2,
                version: '17',
                lang: 'en_US',
                cookieHeader: 'session_id=abc123',
                expiresAt: 123456,
            }),
        };

        const service = new AuthService(
            configService,
            jwtService,
            {} as never,
            {} as never,
            sessionStore as never,
        );

        const response = await service.refresh({ refreshToken: 'refresh-token' });

        expect(jwtService.verifyAsync).toHaveBeenCalledWith('refresh-token', {
            secret: 'test-secret',
        });
        expect(sessionStore.touchOrThrow).toHaveBeenCalledWith('session-handle-123');
        expect(response).toEqual({
            accessToken: 'new-access-token',
            refreshToken: 'new-refresh-token',
            expiresIn: 900,
            user: {
                id: 2,
                name: 'Administrator',
                email: undefined,
                lang: 'en_US',
                tz: undefined,
            },
        });
    });
});