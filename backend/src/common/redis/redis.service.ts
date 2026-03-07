import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleDestroy {
    private readonly logger = new Logger(RedisService.name);
    private client: Redis;

    constructor(private readonly configService: ConfigService) {
        this.client = this.createClient();
    }

    async getJson<T>(key: string): Promise<T | null> {
        const client = await this.getClient();
        const payload = await client.get(key);

        if (!payload) {
            return null;
        }

        return JSON.parse(payload) as T;
    }

    async setJson(key: string, value: unknown, ttlSeconds: number): Promise<void> {
        const client = await this.getClient();
        await client.set(key, JSON.stringify(value), 'EX', ttlSeconds);
    }

    async expire(key: string, ttlSeconds: number): Promise<boolean> {
        const client = await this.getClient();
        return (await client.expire(key, ttlSeconds)) === 1;
    }

    async delete(key: string): Promise<void> {
        const client = await this.getClient();
        await client.del(key);
    }

    async onModuleDestroy(): Promise<void> {
        if (this.client.status === 'end') {
            return;
        }

        if (this.client.status === 'ready' || this.client.status === 'connect') {
            await this.client.quit();
            return;
        }

        this.client.disconnect();
    }

    private createClient(): Redis {
        return new Redis(this.configService.get<string>('REDIS_URL', 'redis://127.0.0.1:6379'), {
            lazyConnect: true,
            maxRetriesPerRequest: 1,
            enableOfflineQueue: false,
            connectTimeout: this.configService.get<number>('REDIS_CONNECT_TIMEOUT_MS', 5000),
        });
    }

    private async getClient(): Promise<Redis> {
        if (this.client.status === 'wait') {
            await this.client.connect();
            this.logger.log({ event: 'redis_connected' });
        }

        if (this.client.status === 'end') {
            this.client = this.createClient();
            await this.client.connect();
            this.logger.log({ event: 'redis_reconnected' });
        }

        return this.client;
    }
}