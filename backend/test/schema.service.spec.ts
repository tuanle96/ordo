import { odooFixtures } from './fixtures/odoo.fixtures';
import { SchemaService } from '../src/modules/schema/schema.service';

describe('SchemaService', () => {
    it('returns cached schema without hitting Odoo when Redis already has it', async () => {
        const adapterFactory = {
            getAdapter: jest.fn(),
        };
        const sessionStore = {
            getOrThrow: jest.fn(),
        };
        const schemaCache = {
            get: jest.fn().mockResolvedValue(odooFixtures.schema),
            set: jest.fn(),
        };
        const service = new SchemaService(
            adapterFactory as never,
            sessionStore as never,
            schemaCache as never,
        );

        await expect(service.getFormSchema(odooFixtures.tokenPayload, 'res.partner')).resolves.toEqual(
            odooFixtures.schema,
        );
        expect(schemaCache.get).toHaveBeenCalledWith(odooFixtures.tokenPayload, 'res.partner');
        expect(sessionStore.getOrThrow).not.toHaveBeenCalled();
        expect(adapterFactory.getAdapter).not.toHaveBeenCalled();
        expect(schemaCache.set).not.toHaveBeenCalled();
    });

    it('reads from Odoo on cache miss and stores the schema back into Redis', async () => {
        const adapter = {
            getFormSchema: jest.fn().mockResolvedValue(odooFixtures.schema),
        };
        const adapterFactory = {
            getAdapter: jest.fn().mockReturnValue(adapter),
        };
        const sessionStore = {
            getOrThrow: jest.fn().mockResolvedValue({ cookieHeader: 'session_id=abc123' }),
        };
        const schemaCache = {
            get: jest.fn().mockResolvedValue(null),
            set: jest.fn().mockResolvedValue(undefined),
        };
        const service = new SchemaService(
            adapterFactory as never,
            sessionStore as never,
            schemaCache as never,
        );

        await expect(service.getFormSchema(odooFixtures.tokenPayload, 'res.partner')).resolves.toEqual(
            odooFixtures.schema,
        );
        expect(sessionStore.getOrThrow).toHaveBeenCalledWith('session-handle-123');
        expect(adapterFactory.getAdapter).toHaveBeenCalledWith('17');
        expect(adapter.getFormSchema).toHaveBeenCalledWith(
            { cookieHeader: 'session_id=abc123' },
            'res.partner',
        );
        expect(schemaCache.set).toHaveBeenCalledWith(
            odooFixtures.tokenPayload,
            'res.partner',
            odooFixtures.schema,
        );
    });
});