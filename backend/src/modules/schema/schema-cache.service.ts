import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import type { MobileFormSchema, TokenPayload } from '@ordo/shared';

import { RedisService } from '../../common/redis/redis.service';

@Injectable()
export class SchemaCacheService {
    private readonly logger = new Logger(SchemaCacheService.name);
    private readonly ttlSeconds = 3600;
    private readonly redisKeyPrefix: string;
    private readonly shouldLog: boolean;

    constructor(
        private readonly configService: ConfigService,
        private readonly redisService: RedisService,
    ) {
        this.redisKeyPrefix = this.configService.get<string>('REDIS_KEY_PREFIX', 'ordo');
        this.shouldLog = this.configService.get<string>('NODE_ENV', process.env.NODE_ENV ?? 'development') !== 'test';
    }

    buildKey(currentUser: TokenPayload, model: string): string {
        const normalizedUrl = new URL(currentUser.odooUrl).toString().replace(/\/$/, '');

        return [
            this.redisKeyPrefix,
            'schema',
            this.normalizeSegment(normalizedUrl),
            this.normalizeSegment(currentUser.db),
            this.normalizeSegment(currentUser.version),
            String(currentUser.uid),
            this.normalizeSegment(currentUser.lang),
            this.normalizeSegment(model),
        ].join(':');
    }

    async get(currentUser: TokenPayload, model: string): Promise<MobileFormSchema | null> {
        try {
            return await this.redisService.getJson<MobileFormSchema>(this.buildKey(currentUser, model));
        } catch (error) {
            this.warn({
                event: 'schema_cache_read_failed',
                db: currentUser.db,
                model,
                error: this.describeError(error),
            });

            return null;
        }
    }

    async set(currentUser: TokenPayload, model: string, schema: MobileFormSchema): Promise<void> {
        try {
            await this.redisService.setJson(
                this.buildKey(currentUser, model),
                schema,
                this.ttlSeconds,
            );
        } catch (error) {
            this.warn({
                event: 'schema_cache_write_failed',
                db: currentUser.db,
                model,
                error: this.describeError(error),
            });
        }
    }

    private warn(payload: Record<string, unknown>): void {
        if (!this.shouldLog) {
            return;
        }

        this.logger.warn(payload);
    }

    private normalizeSegment(value: string): string {
        return encodeURIComponent(value.trim());
    }

    private describeError(error: unknown): string {
        return error instanceof Error ? error.message : 'unknown error';
    }
}