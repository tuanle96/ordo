import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';

import { RedisService } from '@app/common/redis/redis.service';
import type { OdooSessionContext } from '@app/odoo/session/odoo-session.types';

@Injectable()
export class OdooSessionStoreService {
    private readonly keyPrefix: string;

    constructor(
        private readonly configService: ConfigService,
        private readonly redisService: RedisService,
    ) {
        this.keyPrefix = `${this.configService.get<string>('REDIS_KEY_PREFIX', 'ordo')}:session`;
    }

    async create(session: Omit<OdooSessionContext, 'handle' | 'expiresAt'>): Promise<OdooSessionContext> {
        const created: OdooSessionContext = {
            ...session,
            handle: randomUUID(),
            expiresAt: this.computeExpiry(),
        };

        await this.redisService.setJson(this.toKey(created.handle), created, this.getTtlSeconds());
        return created;
    }

    async get(handle: string): Promise<OdooSessionContext | null> {
        const session = await this.redisService.getJson<OdooSessionContext>(this.toKey(handle));
        if (!session) {
            return null;
        }

        if (session.expiresAt <= Date.now()) {
            await this.redisService.delete(this.toKey(handle));
            return null;
        }

        return session;
    }

    async getOrThrow(handle: string): Promise<OdooSessionContext> {
        const session = await this.get(handle);
        if (!session) {
            throw new UnauthorizedException('Upstream Odoo session expired. Please log in again.');
        }

        return session;
    }

    async touch(handle: string): Promise<OdooSessionContext | null> {
        const session = await this.get(handle);
        if (!session) {
            return null;
        }

        const refreshed: OdooSessionContext = {
            ...session,
            expiresAt: this.computeExpiry(),
        };
        await this.redisService.setJson(this.toKey(handle), refreshed, this.getTtlSeconds());
        return refreshed;
    }

    async touchOrThrow(handle: string): Promise<OdooSessionContext> {
        const session = await this.touch(handle);
        if (!session) {
            throw new UnauthorizedException('Upstream Odoo session expired. Please log in again.');
        }

        return session;
    }

    async revoke(handle: string): Promise<void> {
        await this.redisService.delete(this.toKey(handle));
    }

    private computeExpiry(): number {
        return Date.now() + this.getTtlSeconds() * 1000;
    }

    private getTtlSeconds(): number {
        return this.configService.get<number>('ODOO_SESSION_TTL_SECONDS', 1800);
    }

    private toKey(handle: string): string {
        return `${this.keyPrefix}:${handle}`;
    }
}