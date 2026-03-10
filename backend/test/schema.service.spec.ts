import { SchemaService } from '@app/modules/schema/schema.service';
import { odooFixtures } from '@test/fixtures/odoo.fixtures';

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
        expect(schemaCache.get).toHaveBeenCalledWith(odooFixtures.tokenPayload, 'form', 'res.partner');
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
            'form',
            'res.partner',
            odooFixtures.schema,
        );
    });

    it('returns cached list schema without hitting Odoo when Redis already has it', async () => {
        const listSchema = {
            model: 'res.partner',
            title: 'Partners',
            columns: [{ name: 'name', type: 'char', label: 'Name' }],
            search: { fields: [], filters: [], groupBy: [] },
        };
        const adapterFactory = {
            getAdapter: jest.fn(),
        };
        const sessionStore = {
            getOrThrow: jest.fn(),
        };
        const schemaCache = {
            get: jest.fn().mockResolvedValue(listSchema),
            set: jest.fn(),
        };
        const service = new SchemaService(
            adapterFactory as never,
            sessionStore as never,
            schemaCache as never,
        );

        await expect(service.getListSchema(odooFixtures.tokenPayload, 'res.partner')).resolves.toEqual(listSchema);
        expect(schemaCache.get).toHaveBeenCalledWith(odooFixtures.tokenPayload, 'list', 'res.partner');
        expect(sessionStore.getOrThrow).not.toHaveBeenCalled();
        expect(adapterFactory.getAdapter).not.toHaveBeenCalled();
        expect(schemaCache.set).not.toHaveBeenCalled();
    });

    it('reads list schema from Odoo on cache miss and stores it back into Redis', async () => {
        const listSchema = {
            model: 'res.partner',
            title: 'Partners',
            columns: [{ name: 'name', type: 'char', label: 'Name' }],
            search: { fields: [], filters: [], groupBy: [] },
        };
        const adapter = {
            getListSchema: jest.fn().mockResolvedValue(listSchema),
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

        await expect(service.getListSchema(odooFixtures.tokenPayload, 'res.partner')).resolves.toEqual(listSchema);
        expect(sessionStore.getOrThrow).toHaveBeenCalledWith('session-handle-123');
        expect(adapterFactory.getAdapter).toHaveBeenCalledWith('17');
        expect(adapter.getListSchema).toHaveBeenCalledWith(
            { cookieHeader: 'session_id=abc123' },
            'res.partner',
        );
        expect(schemaCache.set).toHaveBeenCalledWith(
            odooFixtures.tokenPayload,
            'list',
            'res.partner',
            listSchema,
        );
    });
});