import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';

import type { OdooSessionContext } from './odoo-session.types';

@Injectable()
export class OdooSessionStoreService {
    private readonly sessions = new Map<string, OdooSessionContext>();

    constructor(private readonly configService: ConfigService) { }

    create(session: Omit<OdooSessionContext, 'handle' | 'expiresAt'>): OdooSessionContext {
        this.cleanupExpired();

        const ttlSeconds = this.configService.get<number>('ODOO_SESSION_TTL_SECONDS', 1800);
        const created: OdooSessionContext = {
            ...session,
            handle: randomUUID(),
            expiresAt: Date.now() + ttlSeconds * 1000,
        };

        this.sessions.set(created.handle, created);
        return created;
    }

    get(handle: string): OdooSessionContext | null {
        const session = this.sessions.get(handle);
        if (!session) {
            return null;
        }

        if (session.expiresAt <= Date.now()) {
            this.sessions.delete(handle);
            return null;
        }

        return session;
    }

    getOrThrow(handle: string): OdooSessionContext {
        const session = this.get(handle);
        if (!session) {
            throw new UnauthorizedException('Upstream Odoo session expired. Please log in again.');
        }

        return session;
    }

    private cleanupExpired(): void {
        const now = Date.now();
        for (const [handle, session] of this.sessions.entries()) {
            if (session.expiresAt <= now) {
                this.sessions.delete(handle);
            }
        }
    }
}