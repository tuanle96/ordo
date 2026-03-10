import type { ConfigService } from '@nestjs/config';
import type { MobileFormSchema } from '@app/shared';

import { SchemaCacheService } from '@app/modules/schema/schema-cache.service';
import { odooFixtures } from '@test/fixtures/odoo.fixtures';

describe('SchemaCacheService', () => {
    const schema: MobileFormSchema = {
        model: 'res.partner',
        title: 'Partners',
        header: { actions: [] },
        sections: [
            {
                label: null,
                fields: [
                    {
                        name: 'name',
                        type: 'char',
                        label: 'Name',
                        required: true,
                        readonly: false,
                        searchable: false,
                    },
                ],
            },
        ],
        tabs: [],
        hasChatter: false,
    };

    it('builds conservative keys using tenant, user, lang, version, and model dimensions', () => {
        const configService = {
            get: jest.fn((key: string, fallback?: string) => (key === 'REDIS_KEY_PREFIX' ? 'ordo' : fallback)),
        } as unknown as ConfigService;
        const redisService = {
            getJson: jest.fn(),
            setJson: jest.fn(),
        };
        const service = new SchemaCacheService(configService, redisService as never);

        const key = service.buildKey(
            {
                ...odooFixtures.tokenPayload,
                odooUrl: 'http://127.0.0.1:38421/',
            },
            'form',
            'res.partner',
        );

        expect(key).toBe('ordo:schema:form:http%3A%2F%2F127.0.0.1%3A38421:odoo17:17:2:en_US:res.partner');
    });

    it('uses a fixed 1 hour ttl when caching schemas', async () => {
        const configService = {
            get: jest.fn((key: string, fallback?: string) => (key === 'REDIS_KEY_PREFIX' ? 'ordo' : fallback)),
        } as unknown as ConfigService;
        const redisService = {
            getJson: jest.fn(),
            setJson: jest.fn().mockResolvedValue(undefined),
        };
        const service = new SchemaCacheService(configService, redisService as never);

        await service.set(odooFixtures.tokenPayload, 'form', 'res.partner', schema);

        expect(redisService.setJson).toHaveBeenCalledWith(
            'ordo:schema:form:http%3A%2F%2F127.0.0.1%3A38421:odoo17:17:2:en_US:res.partner',
            schema,
            3600,
        );
    });

    it('fails open when Redis reads or writes fail', async () => {
        const configService = {
            get: jest.fn((key: string, fallback?: string) => (key === 'REDIS_KEY_PREFIX' ? 'ordo' : fallback)),
        } as unknown as ConfigService;
        const redisService = {
            getJson: jest.fn().mockRejectedValue(new Error('redis down')),
            setJson: jest.fn().mockRejectedValue(new Error('redis down')),
        };
        const service = new SchemaCacheService(configService, redisService as never);

        await expect(service.get(odooFixtures.tokenPayload, 'form', 'res.partner')).resolves.toBeNull();
        await expect(
            service.set(odooFixtures.tokenPayload, 'form', 'res.partner', schema),
        ).resolves.toBeUndefined();
    });

    it('builds separate keys for form, list, and kanban schema segments', () => {
        const configService = {
            get: jest.fn((key: string, fallback?: string) => (key === 'REDIS_KEY_PREFIX' ? 'ordo' : fallback)),
        } as unknown as ConfigService;
        const redisService = {
            getJson: jest.fn(),
            setJson: jest.fn(),
        };
        const service = new SchemaCacheService(configService, redisService as never);

        const formKey = service.buildKey(odooFixtures.tokenPayload, 'form', 'res.partner');
        const listKey = service.buildKey(odooFixtures.tokenPayload, 'list', 'res.partner');
        const kanbanKey = service.buildKey(odooFixtures.tokenPayload, 'kanban', 'crm.lead');

        expect(formKey).not.toBe(listKey);
        expect(listKey).not.toBe(kanbanKey);
        expect(formKey).toContain(':form:');
        expect(listKey).toContain(':list:');
        expect(kanbanKey).toContain(':kanban:');
    });
});