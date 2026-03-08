import type { ChatterDetailsResult, ChatterMessage, ChatterThreadResult } from '@ordo/shared';

import { RecordService } from '../src/modules/record/record.service';
import { odooFixtures } from './fixtures/odoo.fixtures';

describe('RecordService chatter', () => {
    it('delegates chatter listing to the resolved adapter', async () => {
        const thread: ChatterThreadResult = { messages: [], limit: 20, hasMore: false };
        const adapter = { listChatter: jest.fn().mockResolvedValue(thread) };
        const adapterFactory = { getAdapter: jest.fn().mockReturnValue(adapter) };
        const sessionStore = { getOrThrow: jest.fn().mockResolvedValue({ cookieHeader: 'session_id=abc123' }) };
        const service = new RecordService(adapterFactory as never, sessionStore as never);

        await expect(service.listChatter(odooFixtures.tokenPayload as never, 'res.partner', 3, { limit: 20 })).resolves.toEqual(thread);
        expect(sessionStore.getOrThrow).toHaveBeenCalledWith('session-handle-123');
        expect(adapterFactory.getAdapter).toHaveBeenCalledWith('17');
        expect(adapter.listChatter).toHaveBeenCalledWith({ cookieHeader: 'session_id=abc123' }, 'res.partner', 3, 20, undefined);
    });

    it('delegates note posting to the resolved adapter', async () => {
        const message: ChatterMessage = {
            id: 91,
            body: '<p>Internal note</p>',
            plainBody: 'Internal note',
            date: '2026-03-08 10:00:00',
            messageType: 'comment',
            isNote: true,
            isDiscussion: false,
            author: { id: 7, name: 'Administrator', type: 'partner' },
        };
        const adapter = { postChatterNote: jest.fn().mockResolvedValue(message) };
        const adapterFactory = { getAdapter: jest.fn().mockReturnValue(adapter) };
        const sessionStore = { getOrThrow: jest.fn().mockResolvedValue({ cookieHeader: 'session_id=abc123' }) };
        const service = new RecordService(adapterFactory as never, sessionStore as never);

        await expect(service.postChatterNote(odooFixtures.tokenPayload as never, 'res.partner', 3, { body: 'Internal note' })).resolves.toEqual(message);
        expect(sessionStore.getOrThrow).toHaveBeenCalledWith('session-handle-123');
        expect(adapterFactory.getAdapter).toHaveBeenCalledWith('17');
        expect(adapter.postChatterNote).toHaveBeenCalledWith({ cookieHeader: 'session_id=abc123' }, 'res.partner', 3, 'Internal note');
    });

    it('delegates chatter details loading to the resolved adapter', async () => {
        const details: ChatterDetailsResult = {
            followers: [],
            followersCount: 0,
            selfFollower: undefined,
            activities: [],
            availableActivityTypes: [],
        };
        const adapter = { getChatterDetails: jest.fn().mockResolvedValue(details) };
        const adapterFactory = { getAdapter: jest.fn().mockReturnValue(adapter) };
        const sessionStore = { getOrThrow: jest.fn().mockResolvedValue({ cookieHeader: 'session_id=abc123' }) };
        const service = new RecordService(adapterFactory as never, sessionStore as never);

        await expect(service.getChatterDetails(odooFixtures.tokenPayload as never, 'res.partner', 3)).resolves.toEqual(details);
        expect(adapter.getChatterDetails).toHaveBeenCalledWith({ cookieHeader: 'session_id=abc123' }, 'res.partner', 3);
    });

    it('delegates follow and unfollow requests to the resolved adapter', async () => {
        const details: ChatterDetailsResult = {
            followers: [],
            followersCount: 0,
            selfFollower: undefined,
            activities: [],
            availableActivityTypes: [],
        };
        const adapter = {
            followRecord: jest.fn().mockResolvedValue(details),
            unfollowRecord: jest.fn().mockResolvedValue(details),
        };
        const adapterFactory = { getAdapter: jest.fn().mockReturnValue(adapter) };
        const sessionStore = { getOrThrow: jest.fn().mockResolvedValue({ cookieHeader: 'session_id=abc123' }) };
        const service = new RecordService(adapterFactory as never, sessionStore as never);

        await expect(service.followRecord(odooFixtures.tokenPayload as never, 'res.partner', 3)).resolves.toEqual(details);
        await expect(service.unfollowRecord(odooFixtures.tokenPayload as never, 'res.partner', 3)).resolves.toEqual(details);

        expect(adapter.followRecord).toHaveBeenCalledWith({ cookieHeader: 'session_id=abc123' }, 'res.partner', 3);
        expect(adapter.unfollowRecord).toHaveBeenCalledWith({ cookieHeader: 'session_id=abc123' }, 'res.partner', 3);
    });

    it('delegates chatter activity completion to the resolved adapter', async () => {
        const details: ChatterDetailsResult = {
            followers: [],
            followersCount: 0,
            selfFollower: undefined,
            activities: [],
            availableActivityTypes: [],
        };
        const adapter = { completeChatterActivity: jest.fn().mockResolvedValue(details) };
        const adapterFactory = { getAdapter: jest.fn().mockReturnValue(adapter) };
        const sessionStore = { getOrThrow: jest.fn().mockResolvedValue({ cookieHeader: 'session_id=abc123' }) };
        const service = new RecordService(adapterFactory as never, sessionStore as never);

        await expect(service.completeChatterActivity(odooFixtures.tokenPayload as never, 'res.partner', 3, 44, { feedback: 'Done' })).resolves.toEqual(details);
        expect(adapter.completeChatterActivity).toHaveBeenCalledWith({ cookieHeader: 'session_id=abc123' }, 'res.partner', 3, 44, 'Done');
    });

    it('delegates chatter activity scheduling to the resolved adapter', async () => {
        const details: ChatterDetailsResult = {
            followers: [],
            followersCount: 0,
            selfFollower: undefined,
            activities: [],
            availableActivityTypes: [],
        };
        const adapter = { scheduleChatterActivity: jest.fn().mockResolvedValue(details) };
        const adapterFactory = { getAdapter: jest.fn().mockReturnValue(adapter) };
        const sessionStore = { getOrThrow: jest.fn().mockResolvedValue({ cookieHeader: 'session_id=abc123' }) };
        const service = new RecordService(adapterFactory as never, sessionStore as never);

        await expect(service.scheduleChatterActivity(odooFixtures.tokenPayload as never, 'res.partner', 3, {
            activityTypeId: 5,
            summary: 'Call customer',
            note: 'Ask for update',
            dateDeadline: '2026-03-12',
        })).resolves.toEqual(details);
        expect(adapter.scheduleChatterActivity).toHaveBeenCalledWith(
            { cookieHeader: 'session_id=abc123' },
            'res.partner',
            3,
            5,
            { summary: 'Call customer', note: 'Ask for update', dateDeadline: '2026-03-12' },
        );
    });

    it('delegates onchange requests to the resolved adapter', async () => {
        const result = {
            values: { name: 'Acme' },
            warnings: [{ title: 'Heads up', message: 'Updated from onchange.' }],
        };
        const adapter = { runOnchange: jest.fn().mockResolvedValue(result) };
        const adapterFactory = { getAdapter: jest.fn().mockReturnValue(adapter) };
        const sessionStore = { getOrThrow: jest.fn().mockResolvedValue({ cookieHeader: 'session_id=abc123' }) };
        const service = new RecordService(adapterFactory as never, sessionStore as never);

        await expect(service.runOnchange(odooFixtures.tokenPayload as never, 'res.partner', {
            values: { country_id: 21 },
            triggerField: 'country_id',
            recordId: 3,
            fields: ['id', 'name', 'country_id'],
        } as never)).resolves.toEqual(result);

        expect(sessionStore.getOrThrow).toHaveBeenCalledWith('session-handle-123');
        expect(adapterFactory.getAdapter).toHaveBeenCalledWith('17');
        expect(adapter.runOnchange).toHaveBeenCalledWith(
            { cookieHeader: 'session_id=abc123' },
            'res.partner',
            {
                values: { country_id: 21 },
                triggerField: 'country_id',
                recordId: 3,
                fields: ['id', 'name', 'country_id'],
            },
        );
    });
});