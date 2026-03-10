import { UnauthorizedException } from '@nestjs/common';
import type { ConfigService } from '@nestjs/config';

import { OdooSessionStoreService } from '@app/odoo/session/odoo-session-store.service';

class FakeRedisService {
    private readonly store = new Map<string, { value: string; expiresAt: number }>();

    constructor(private readonly now: () => number) { }

    async getJson<T>(key: string): Promise<T | null> {
        const entry = this.store.get(key);
        if (!entry) {
            return null;
        }

        if (entry.expiresAt <= this.now()) {
            this.store.delete(key);
            return null;
        }

        return JSON.parse(entry.value) as T;
    }

    async setJson(key: string, value: unknown, ttlSeconds: number): Promise<void> {
        this.store.set(key, {
            value: JSON.stringify(value),
            expiresAt: this.now() + ttlSeconds * 1000,
        });
    }

    async delete(key: string): Promise<void> {
        this.store.delete(key);
    }
}

describe('OdooSessionStoreService', () => {
    afterEach(() => {
        jest.restoreAllMocks();
    });

    it('creates sessions with TTL and expires them on lookup', async () => {
        const configService = {
            get: jest.fn().mockReturnValue(1),
        } as unknown as ConfigService;
        const redisService = new FakeRedisService(() => Date.now());
        const service = new OdooSessionStoreService(configService, redisService as never);

        jest.spyOn(Date, 'now').mockReturnValue(1_000);
        const session = await service.create({
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
        await expect(service.get(session.handle)).resolves.toEqual(session);

        jest.spyOn(Date, 'now').mockReturnValue(2_001);
        await expect(service.get(session.handle)).resolves.toBeNull();
        await expect(service.getOrThrow(session.handle)).rejects.toThrow(UnauthorizedException);
    });

    it('touches active sessions and extends their TTL', async () => {
        const configService = {
            get: jest.fn().mockReturnValue(10),
        } as unknown as ConfigService;
        const redisService = new FakeRedisService(() => Date.now());
        const service = new OdooSessionStoreService(configService, redisService as never);

        jest.spyOn(Date, 'now').mockReturnValue(1_000);
        const session = await service.create({
            odooUrl: 'http://127.0.0.1:38421',
            db: 'odoo17',
            uid: 2,
            version: '17',
            lang: 'en_US',
            cookieHeader: 'session_id=abc',
        });

        jest.spyOn(Date, 'now').mockReturnValue(5_000);
        const touched = await service.touch(session.handle);

        expect(touched).toEqual({
            ...session,
            expiresAt: 15_000,
        });
        await expect(service.get(session.handle)).resolves.toEqual({
            ...session,
            expiresAt: 15_000,
        });
    });
});