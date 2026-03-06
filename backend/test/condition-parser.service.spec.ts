import { ConditionParserService } from '../src/odoo/schema/condition-parser.service';

describe('ConditionParserService', () => {
    const service = new ConditionParserService();

    it('parses scalar invisible expressions', () => {
        expect(service.parseInvisible("state == 'done'")).toEqual({
            field: 'state',
            op: '==',
            value: 'done',
        });
    });

    it('parses list invisible expressions', () => {
        expect(service.parseInvisible("stage in ['draft', 'cancel']")).toEqual({
            field: 'stage',
            op: 'in',
            values: ['draft', 'cancel'],
        });
    });

    it('returns undefined for missing or unsupported expressions', () => {
        expect(service.parseInvisible()).toBeUndefined();
        expect(service.parseInvisible('bad syntax here')).toBeUndefined();
    });
});