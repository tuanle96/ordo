import type { ChatterMessage, ChatterThreadResult } from '@ordo/shared';

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
});