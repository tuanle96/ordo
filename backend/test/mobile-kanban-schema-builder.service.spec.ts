import { MobileKanbanSchemaBuilderService } from '@app/odoo/schema/mobile-kanban-schema-builder.service';
import { ConditionParserService } from '@app/odoo/schema/condition-parser.service';

describe('MobileKanbanSchemaBuilderService', () => {
    const service = new MobileKanbanSchemaBuilderService(new ConditionParserService());

    it('parses a minimal kanban arch into a mobile kanban schema', () => {
        const schema = service.build(
            'crm.lead',
            [
                '<kanban string="Leads" default_group_by="stage_id" highlight_color="color">',
                '<field name="stage_id" />',
                '<field name="name" />',
                '<field name="partner_name" />',
                '<templates><t t-name="kanban-box"><div><field name="name" /><field name="partner_name" /></div></t></templates>',
                '</kanban>',
            ].join(''),
            '<search><field name="name" /><filter name="my" string="My Leads" domain="[(\'user_id\',\'=\',uid)]" /></search>',
            {
                stage_id: { type: 'many2one', string: 'Stage', relation: 'crm.stage' },
                name: { type: 'char', string: 'Opportunity' },
                partner_name: { type: 'char', string: 'Customer' },
                color: { type: 'integer', string: 'Color' },
            },
        );

        expect(schema).toEqual({
            model: 'crm.lead',
            title: 'Leads',
            groupByField: 'stage_id',
            groupBySelection: undefined,
            cardFields: [
                { name: 'name', type: 'char', label: 'Opportunity', widget: undefined, comodel: undefined },
                { name: 'partner_name', type: 'char', label: 'Customer', widget: undefined, comodel: undefined },
            ],
            cardButtons: [],
            colorField: 'color',
            search: {
                fields: [{ name: 'name', label: 'Opportunity', type: 'char', filterDomain: undefined, selection: undefined }],
                filters: [{ name: 'my', label: 'My Leads', domain: '[["user_id","=","uid"]]' }],
            },
        });
    });

    it('returns a flat schema when the kanban arch has no default group by', () => {
        const schema = service.build(
            'crm.lead',
            '<kanban string="Leads"><templates><t t-name="kanban-box"><div><field name="name" /></div></t></templates></kanban>',
            undefined,
            { name: { type: 'char', string: 'Opportunity' } },
        );

        expect(schema).not.toBeNull();
        expect(schema!.groupByField).toBeUndefined();
        expect(schema!.groupBySelection).toBeUndefined();
        expect(schema!.cardFields.map((f) => f.name)).toContain('name');
    });

    it('parses type=object buttons from kanban arch with invisible conditions', () => {
        const schema = service.build(
            'ir.module.module',
            [
                '<kanban string="Apps">',
                '<field name="name" />',
                '<field name="state" />',
                '<templates><t t-name="kanban-box"><div>',
                '<field name="name" />',
                '<button type="object" class="btn btn-primary btn-sm" name="button_immediate_install" invisible="state != \'uninstalled\'">Activate</button>',
                '<a href="https://example.com" class="btn btn-sm btn-secondary" role="button">Learn More</a>',
                '<button invisible="state != \'to remove\'" type="object" class="btn btn-sm btn-primary" name="button_uninstall_cancel" string="Cancel Uninstall" />',
                '</div></t></templates>',
                '</kanban>',
            ].join(''),
            undefined,
            {
                name: { type: 'char', string: 'Module' },
                state: { type: 'selection', string: 'Status' },
            },
        );

        expect(schema).not.toBeNull();
        expect(schema!.cardButtons).toHaveLength(2);

        expect(schema!.cardButtons[0]).toEqual({
            name: 'button_immediate_install',
            label: 'Activate',
            type: 'object',
            style: 'primary',
            invisible: {
                type: 'condition',
                condition: { field: 'state', op: '!=', value: 'uninstalled' },
            },
        });

        expect(schema!.cardButtons[1]).toEqual({
            name: 'button_uninstall_cancel',
            label: 'Cancel Uninstall',
            type: 'object',
            style: 'primary',
            invisible: {
                type: 'condition',
                condition: { field: 'state', op: '!=', value: 'to remove' },
            },
        });
    });

    it('skips buttons without type=object', () => {
        const schema = service.build(
            'test.model',
            [
                '<kanban string="Test">',
                '<field name="name" />',
                '<templates><t t-name="kanban-box"><div>',
                '<field name="name" />',
                '<button type="action" name="%(some_action)d" string="Open" />',
                '</div></t></templates>',
                '</kanban>',
            ].join(''),
            undefined,
            { name: { type: 'char', string: 'Name' } },
        );

        expect(schema).not.toBeNull();
        expect(schema!.cardButtons).toHaveLength(0);
    });
});