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

    it('parses nested boolean modifier expressions into rule trees', () => {
        expect(service.parseRule("state == 'done' or (priority >= 3 and not is_company == true)")).toEqual({
            type: 'or',
            rules: [
                {
                    type: 'condition',
                    condition: { field: 'state', op: '==', value: 'done' },
                },
                {
                    type: 'and',
                    rules: [
                        {
                            type: 'condition',
                            condition: { field: 'priority', op: '>=', value: 3 },
                        },
                        {
                            type: 'not',
                            rules: [
                                {
                                    type: 'condition',
                                    condition: { field: 'is_company', op: '==', value: true },
                                },
                            ],
                        },
                    ],
                },
            ],
        });
    });

    it('parses Odoo prefix domain arrays into rule trees', () => {
        expect(service.parseRule("['&', ('state', '=', 'draft'), '|', ('company_id', 'in', [1, 2]), ('active', '=', True)]")).toEqual({
            type: 'and',
            rules: [
                {
                    type: 'condition',
                    condition: { field: 'state', op: '==', value: 'draft' },
                },
                {
                    type: 'or',
                    rules: [
                        {
                            type: 'condition',
                            condition: { field: 'company_id', op: 'in', values: [1, 2] },
                        },
                        {
                            type: 'condition',
                            condition: { field: 'active', op: '==', value: true },
                        },
                    ],
                },
            ],
        });
    });

    it('parses states attribute into invisible rule', () => {
        expect(service.parseStates('draft,done')).toEqual({
            type: 'condition',
            condition: {
                field: 'state',
                op: 'not in',
                values: ['draft', 'done'],
            },
        });
    });

    it('returns undefined for missing or unsupported expressions', () => {
        expect(service.parseInvisible()).toBeUndefined();
        expect(service.parseInvisible('bad syntax here')).toBeUndefined();
        expect(service.parseRule("company_id == allowed_company_ids[0]")).toBeUndefined();
    });
});