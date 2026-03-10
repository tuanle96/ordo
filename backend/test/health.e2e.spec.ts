import type { INestApplication } from '@nestjs/common';
import request from 'supertest';

import { createTestApp } from '@test/helpers/create-test-app';

describe('HealthController', () => {
    let app: INestApplication;

    beforeAll(async () => {
        app = await createTestApp();
    });

    afterAll(async () => {
        await app.close();
    });

    it('returns the unprefixed health envelope', async () => {
        const response = await request(app.getHttpServer())
            .get('/health')
            .expect(200);

        expect(response.body.success).toBe(true);
        expect(response.body.errors).toEqual([]);
        expect(response.body.data.service).toBe('ordo-backend');
        expect(response.body.data.status).toBe('ok');
        expect(typeof response.body.data.timestamp).toBe('string');
        expect(typeof response.body.meta.timestamp).toBe('string');
    });
});