import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import type { MobileFormSchema, MobileKanbanSchema, MobileListSchema, TokenPayload } from '@app/shared';

import { RedisService } from '@app/common/redis/redis.service';

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

    buildKey(currentUser: TokenPayload, segment: 'form' | 'kanban' | 'list', model: string): string {
        const normalizedUrl = new URL(currentUser.odooUrl).toString().replace(/\/$/, '');

        return [
            this.redisKeyPrefix,
            'schema',
            segment,
            this.normalizeSegment(normalizedUrl),
            this.normalizeSegment(currentUser.db),
            this.normalizeSegment(currentUser.version),
            String(currentUser.uid),
            this.normalizeSegment(currentUser.lang),
            this.normalizeSegment(model),
        ].join(':');
    }

    async get<T extends MobileFormSchema | MobileKanbanSchema | MobileListSchema>(
        currentUser: TokenPayload,
        segment: 'form' | 'kanban' | 'list',
        model: string,
    ): Promise<T | null> {
        try {
            return await this.redisService.getJson<T>(this.buildKey(currentUser, segment, model));
        } catch (error) {
            this.warn({
                event: 'schema_cache_read_failed',
                segment,
                db: currentUser.db,
                model,
                error: this.describeError(error),
            });

            return null;
        }
    }

    async set<T extends MobileFormSchema | MobileKanbanSchema | MobileListSchema>(
        currentUser: TokenPayload,
        segment: 'form' | 'kanban' | 'list',
        model: string,
        schema: T,
    ): Promise<void> {
        try {
            await this.redisService.setJson(
                this.buildKey(currentUser, segment, model),
                schema,
                this.ttlSeconds,
            );
        } catch (error) {
            this.warn({
                event: 'schema_cache_write_failed',
                segment,
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