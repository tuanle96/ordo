import type { INestApplication } from '@nestjs/common';
import request from 'supertest';

import { RecordService } from '../src/modules/record/record.service';
import { odooFixtures } from './fixtures/odoo.fixtures';
import { createAccessToken } from './helpers/create-access-token';
import { createTestApp } from './helpers/create-test-app';

describe('Record chatter endpoints', () => {
    let app: INestApplication;
    let accessToken: string;

    const chatterThread = {
        messages: [
            {
                id: 91,
                body: '<p>Internal note</p>',
                plainBody: 'Internal note',
                date: '2026-03-08 10:00:00',
                messageType: 'comment',
                isNote: true,
                isDiscussion: false,
                author: { id: 7, name: 'Administrator', type: 'partner' as const },
            },
        ],
        limit: 20,
        hasMore: false,
    };

    const chatterDetails = {
        followers: [
            {
                id: 15,
                partnerId: 7,
                name: 'Administrator',
                email: 'admin@example.com',
                isActive: true,
                isSelf: true,
            },
        ],
        followersCount: 1,
        selfFollower: {
            id: 15,
            partnerId: 7,
            name: 'Administrator',
            email: 'admin@example.com',
            isActive: true,
            isSelf: true,
        },
        activities: [
            {
                id: 44,
                typeId: 3,
                typeName: 'To Do',
                summary: 'Follow up',
                note: '<p>Call back tomorrow</p>',
                plainNote: 'Call back tomorrow',
                dateDeadline: '2026-03-10',
                state: 'planned',
                canWrite: true,
                assignedUser: { id: 2, name: 'Administrator' },
            },
        ],
    };

    const recordServiceMock = {
        listRecords: jest.fn(),
        getRecord: jest.fn(),
        createRecord: jest.fn(),
        updateRecord: jest.fn(),
        deleteRecord: jest.fn(),
        runRecordAction: jest.fn(),
        search: jest.fn(),
        listChatter: jest.fn().mockResolvedValue(chatterThread),
        getChatterDetails: jest.fn().mockResolvedValue(chatterDetails),
        postChatterNote: jest.fn().mockResolvedValue(chatterThread.messages[0]),
        followRecord: jest.fn().mockResolvedValue(chatterDetails),
        unfollowRecord: jest.fn().mockResolvedValue({ ...chatterDetails, followers: [], followersCount: 0, selfFollower: undefined }),
        completeChatterActivity: jest.fn().mockResolvedValue({ ...chatterDetails, activities: [] }),
    };

    beforeAll(async () => {
        app = await createTestApp([{ token: RecordService, useValue: recordServiceMock }]);
        accessToken = await createAccessToken(app, odooFixtures.tokenPayload);
    });

    afterAll(async () => {
        await app.close();
    });

    it('returns a chatter thread envelope', async () => {
        const response = await request(app.getHttpServer())
            .get('/api/v1/mobile/records/res.partner/3/chatter?limit=20')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(200);

        expect(recordServiceMock.listChatter).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            3,
            expect.objectContaining({ limit: 20 }),
        );
        expect(response.body.data).toEqual(chatterThread);
    });

    it('posts a chatter note and returns the created message envelope', async () => {
        const response = await request(app.getHttpServer())
            .post('/api/v1/mobile/records/res.partner/3/chatter/note')
            .set('Authorization', `Bearer ${accessToken}`)
            .send({ body: 'Internal note' })
            .expect(201);

        expect(recordServiceMock.postChatterNote).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            3,
            expect.objectContaining({ body: 'Internal note' }),
        );
        expect(response.body.data).toEqual(chatterThread.messages[0]);
    });

    it('returns chatter details envelope', async () => {
        const response = await request(app.getHttpServer())
            .get('/api/v1/mobile/records/res.partner/3/chatter/details')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(200);

        expect(recordServiceMock.getChatterDetails).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            3,
        );
        expect(response.body.data).toEqual(chatterDetails);
    });

    it('follows a record and returns refreshed chatter details', async () => {
        const response = await request(app.getHttpServer())
            .post('/api/v1/mobile/records/res.partner/3/chatter/follow')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(201);

        expect(recordServiceMock.followRecord).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            3,
        );
        expect(response.body.data).toEqual(chatterDetails);
    });

    it('marks an activity done and returns refreshed chatter details', async () => {
        const response = await request(app.getHttpServer())
            .post('/api/v1/mobile/records/res.partner/3/chatter/activities/44/done')
            .set('Authorization', `Bearer ${accessToken}`)
            .send({ feedback: 'Done' })
            .expect(201);

        expect(recordServiceMock.completeChatterActivity).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2 }),
            'res.partner',
            3,
            44,
            expect.objectContaining({ feedback: 'Done' }),
        );
        expect(response.body.data).toEqual({ ...chatterDetails, activities: [] });
    });
});