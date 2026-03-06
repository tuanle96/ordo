import type { INestApplication } from '@nestjs/common';
import request from 'supertest';

import { RecordService } from '../src/modules/record/record.service';
import { SchemaService } from '../src/modules/schema/schema.service';
import { odooFixtures } from './fixtures/odoo.fixtures';
import { createAccessToken } from './helpers/create-access-token';
import { createTestApp } from './helpers/create-test-app';

describe('Schema, record, and search endpoints', () => {
    let app: INestApplication;
    let protectedApp: INestApplication;
    let accessToken: string;

    const schemaServiceMock = {
        getFormSchema: jest.fn().mockResolvedValue(odooFixtures.schema),
    };

    const recordServiceMock = {
        listRecords: jest.fn().mockResolvedValue({
            items: odooFixtures.records,
            limit: 3,
            offset: 0,
        }),
        getRecord: jest.fn().mockResolvedValue(odooFixtures.records[0]),
        search: jest.fn().mockResolvedValue(odooFixtures.nameSearch),
    };

    beforeAll(async () => {
        app = await createTestApp();
        protectedApp = await createTestApp([
            { token: SchemaService, useValue: schemaServiceMock },
            { token: RecordService, useValue: recordServiceMock },
        ]);
        accessToken = await createAccessToken(protectedApp, odooFixtures.tokenPayload);
    });

    afterAll(async () => {
        await Promise.all([app.close(), protectedApp.close()]);
    });

    it('rejects /schema/:model without a bearer token', async () => {
        await request(app.getHttpServer())
            .get('/api/v1/mobile/schema/res.partner')
            .expect(401);
    });

    it('returns schema envelope for /schema/:model', async () => {
        const response = await request(protectedApp.getHttpServer())
            .get('/api/v1/mobile/schema/res.partner')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(200);

        expect(schemaServiceMock.getFormSchema).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
        );
        expect(response.body.data).toEqual(odooFixtures.schema);
    });

    it('returns records envelope for list and detail endpoints', async () => {
        const listResponse = await request(protectedApp.getHttpServer())
            .get('/api/v1/mobile/records/res.partner?fields=id,name,email&limit=3')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(200);

        expect(recordServiceMock.listRecords).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            expect.objectContaining({ fields: ['id', 'name', 'email'], limit: 3 }),
        );
        expect(listResponse.body.data.items).toEqual(odooFixtures.records);

        const detailResponse = await request(protectedApp.getHttpServer())
            .get('/api/v1/mobile/records/res.partner/3?fields=id,name,email')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(200);

        expect(recordServiceMock.getRecord).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            3,
            expect.objectContaining({ fields: ['id', 'name', 'email'] }),
        );
        expect(detailResponse.body.data).toEqual(odooFixtures.records[0]);
    });

    it('returns relation search envelope for /search/:model', async () => {
        const response = await request(protectedApp.getHttpServer())
            .get('/api/v1/mobile/search/res.partner?query=Administrator&limit=5')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(200);

        expect(recordServiceMock.search).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            expect.objectContaining({ query: 'Administrator', limit: 5 }),
        );
        expect(response.body.data).toEqual(odooFixtures.nameSearch);
    });
});