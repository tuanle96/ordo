import type { INestApplication } from '@nestjs/common';
import request from 'supertest';

import { RecordService } from '@app/modules/record/record.service';
import { SchemaService } from '@app/modules/schema/schema.service';
import { odooFixtures } from '@test/fixtures/odoo.fixtures';
import { createAccessToken } from '@test/helpers/create-access-token';
import { createTestApp } from '@test/helpers/create-test-app';

describe('Schema, record, and search endpoints', () => {
    let app: INestApplication;
    let protectedApp: INestApplication;
    let accessToken: string;

    const schemaServiceMock = {
        getFormSchema: jest.fn().mockResolvedValue(odooFixtures.schema),
        getListSchema: jest.fn().mockResolvedValue({
            model: 'res.partner',
            title: 'Partners',
            columns: [{ name: 'name', type: 'char', label: 'Name' }],
            search: { fields: [], filters: [], groupBy: [] },
        }),
    };

    const recordServiceMock = {
        listRecords: jest.fn().mockResolvedValue({
            items: odooFixtures.records,
            limit: 3,
            offset: 0,
            total: 3,
        }),
        getDefaultValues: jest.fn().mockResolvedValue({ name: 'Draft Customer', country_id: 21 }),
        getRecord: jest.fn().mockResolvedValue(odooFixtures.records[0]),
        runOnchange: jest.fn().mockResolvedValue({
            values: { name: 'Updated by onchange' },
            warnings: [{ title: 'Heads up', message: 'Partner defaults refreshed.' }],
        }),
        createRecord: jest.fn().mockResolvedValue({ id: 3, record: odooFixtures.records[0] }),
        updateRecord: jest.fn().mockResolvedValue({ id: 3, record: odooFixtures.records[0] }),
        deleteRecord: jest.fn().mockResolvedValue({ id: 3, deleted: true }),
        runRecordAction: jest.fn().mockResolvedValue({
            id: 3,
            changed: true,
            record: odooFixtures.records[0],
        }),
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
            false,
        );
        expect(response.body.data).toEqual(odooFixtures.schema);
    });

    it('returns list schema envelope for /schema/:model/list', async () => {
        const response = await request(protectedApp.getHttpServer())
            .get('/api/v1/mobile/schema/res.partner/list')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(200);

        expect(schemaServiceMock.getListSchema).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            false,
        );
        expect(response.body.data).toEqual({
            model: 'res.partner',
            title: 'Partners',
            columns: [{ name: 'name', type: 'char', label: 'Name' }],
            search: { fields: [], filters: [], groupBy: [] },
        });
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
        expect(listResponse.body.data.total).toBe(3);

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

    it('returns default values envelope for create hydration', async () => {
        const response = await request(protectedApp.getHttpServer())
            .get('/api/v1/mobile/records/res.partner/defaults?fields=name,country_id')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(200);

        expect(recordServiceMock.getDefaultValues).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            expect.objectContaining({ fields: ['name', 'country_id'] }),
        );
        expect(response.body.data).toEqual({ name: 'Draft Customer', country_id: 21 });
    });

    it('returns envelopes for create, update, delete, and action endpoints', async () => {
        const createResponse = await request(protectedApp.getHttpServer())
            .post('/api/v1/mobile/records/res.partner')
            .set('Authorization', `Bearer ${accessToken}`)
            .send({ values: { name: 'Administrator' }, fields: ['id', 'name', 'email'] })
            .expect(201);

        expect(recordServiceMock.createRecord).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            expect.objectContaining({ values: { name: 'Administrator' }, fields: ['id', 'name', 'email'] }),
        );
        expect(createResponse.body.data).toEqual({ id: 3, record: odooFixtures.records[0] });

        const updateResponse = await request(protectedApp.getHttpServer())
            .patch('/api/v1/mobile/records/res.partner/3')
            .set('Authorization', `Bearer ${accessToken}`)
            .send({ values: { name: 'Updated Administrator' }, fields: ['id', 'name', 'email'] })
            .expect(200);

        expect(recordServiceMock.updateRecord).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            3,
            expect.objectContaining({ values: { name: 'Updated Administrator' }, fields: ['id', 'name', 'email'] }),
        );
        expect(updateResponse.body.data).toEqual({ id: 3, record: odooFixtures.records[0] });

        const deleteResponse = await request(protectedApp.getHttpServer())
            .delete('/api/v1/mobile/records/res.partner/3')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(200);

        expect(recordServiceMock.deleteRecord).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            3,
        );
        expect(deleteResponse.body.data).toEqual({ id: 3, deleted: true });

        const actionResponse = await request(protectedApp.getHttpServer())
            .post('/api/v1/mobile/records/res.partner/3/actions/action_archive')
            .set('Authorization', `Bearer ${accessToken}`)
            .send({ fields: ['id', 'name', 'email'] })
            .expect(201);

        expect(recordServiceMock.runRecordAction).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            3,
            'action_archive',
            expect.objectContaining({ fields: ['id', 'name', 'email'] }),
        );
        expect(actionResponse.body.data).toEqual({
            id: 3,
            changed: true,
            record: odooFixtures.records[0],
        });

        const onchangeResponse = await request(protectedApp.getHttpServer())
            .post('/api/v1/mobile/records/res.partner/onchange')
            .set('Authorization', `Bearer ${accessToken}`)
            .send({ values: { country_id: 21 }, triggerField: 'country_id', recordId: 3, fields: ['id', 'name', 'country_id'] })
            .expect(201);

        expect(recordServiceMock.runOnchange).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            expect.objectContaining({ values: { country_id: 21 }, triggerField: 'country_id', recordId: 3, fields: ['id', 'name', 'country_id'] }),
        );
        expect(onchangeResponse.body.data).toEqual({
            values: { name: 'Updated by onchange' },
            warnings: [{ title: 'Heads up', message: 'Partner defaults refreshed.' }],
        });
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

    it('normalizes comma-delimited onchange fields and rejects invalid payloads', async () => {
        await request(protectedApp.getHttpServer())
            .post('/api/v1/mobile/records/res.partner/onchange')
            .set('Authorization', `Bearer ${accessToken}`)
            .send({ values: { country_id: 21 }, triggerField: 'country_id', fields: 'id,name,country_id' })
            .expect(201);

        expect(recordServiceMock.runOnchange).toHaveBeenLastCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            expect.objectContaining({
                values: { country_id: 21 },
                triggerField: 'country_id',
                fields: ['id', 'name', 'country_id'],
            }),
        );

        await request(protectedApp.getHttpServer())
            .post('/api/v1/mobile/records/res.partner/onchange')
            .set('Authorization', `Bearer ${accessToken}`)
            .send({ values: { country_id: 21 } })
            .expect(400);
    });
});