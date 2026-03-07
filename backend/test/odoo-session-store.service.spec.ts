import { UnauthorizedException } from '@nestjs/common';
import type { ConfigService } from '@nestjs/config';

import { OdooSessionStoreService } from '../src/odoo/session/odoo-session-store.service';

describe('OdooSessionStoreService', () => {
    afterEach(() => {
        jest.restoreAllMocks();
    });

    it('creates sessions with TTL and expires them on lookup', () => {
        const configService = {
            get: jest.fn().mockReturnValue(1),
        } as unknown as ConfigService;
        const service = new OdooSessionStoreService(configService);

        jest.spyOn(Date, 'now').mockReturnValue(1_000);
        const session = service.create({
            odooUrl: 'http://127.0.0.1:38421',
            db: 'odoo17',
            uid: 2,
            version: '17',
            lang: 'en_US',
            cookieHeader: 'session_id=abc',
        });

        expect(session.handle).toEqual(expect.any(String));
        expect(session.expiresAt).toBe(2_000);

        jest.spyOn(Date, 'now').mockReturnValue(1_500);
        expect(service.get(session.handle)).toEqual(session);

        jest.spyOn(Date, 'now').mockReturnValue(2_001);
        expect(service.get(session.handle)).toBeNull();
        expect(() => service.getOrThrow(session.handle)).toThrow(UnauthorizedException);
    });

    it('touches active sessions and extends their TTL', () => {
        const configService = {
            get: jest.fn().mockReturnValue(10),
        } as unknown as ConfigService;
        const service = new OdooSessionStoreService(configService);

        jest.spyOn(Date, 'now').mockReturnValue(1_000);
        const session = service.create({
            odooUrl: 'http://127.0.0.1:38421',
            db: 'odoo17',
            uid: 2,
            version: '17',
            lang: 'en_US',
            cookieHeader: 'session_id=abc',
        });

        jest.spyOn(Date, 'now').mockReturnValue(5_000);
        const touched = service.touch(session.handle);

        expect(touched).toEqual({
            ...session,
            expiresAt: 15_000,
        });
        expect(service.get(session.handle)).toEqual({
            ...session,
            expiresAt: 15_000,
        });
    });
});