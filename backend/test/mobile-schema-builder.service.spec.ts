import { ConditionParserService } from '../src/odoo/schema/condition-parser.service';
import { MobileSchemaBuilderService } from '../src/odoo/schema/mobile-schema-builder.service';

describe('MobileSchemaBuilderService', () => {
    it('keeps the supported field matrix stable for canonical mobile-safe types', () => {
        const service = new MobileSchemaBuilderService(new ConditionParserService());
        const xml = `
                        <form string="Matrix">
                            <header>
                                <field name="state" widget="statusbar" />
                            </header>
                            <sheet>
                                <group>
                                    <field name="name" />
                                    <field name="description" />
                                    <field name="sequence" />
                                    <field name="amount_total" />
                                    <field name="credit_limit" />
                                    <field name="is_company" />
                                    <field name="customer_rank" />
                                    <field name="date_order" />
                                    <field name="write_date" />
                                    <field name="country_id" />
                                    <field name="order_line" />
                                    <field name="category_id" />
                                    <field name="attachment" />
                                    <field name="avatar_128" />
                                    <field name="notes_html" />
                                    <field name="priority" />
                                    <field name="signature" />
                                </group>
                            </sheet>
                        </form>
                `;

        const schema = service.build('x.matrix', xml, {
            state: { type: 'selection', string: 'State', selection: [['draft', 'Draft']] },
            name: { type: 'char', string: 'Name' },
            description: { type: 'text', string: 'Description' },
            sequence: { type: 'integer', string: 'Sequence' },
            amount_total: { type: 'float', string: 'Amount Total', digits: [16, 2] },
            credit_limit: { type: 'monetary', string: 'Credit Limit', digits: [16, 2], currency_field: 'currency_id' },
            is_company: { type: 'boolean', string: 'Company' },
            customer_rank: { type: 'selection', string: 'Rank', selection: [['vip', 'VIP']] },
            date_order: { type: 'date', string: 'Order Date' },
            write_date: { type: 'datetime', string: 'Write Date' },
            country_id: { type: 'many2one', string: 'Country', relation: 'res.country' },
            order_line: { type: 'one2many', string: 'Order Lines', relation: 'sale.order.line' },
            category_id: { type: 'many2many', string: 'Tags', relation: 'res.partner.category' },
            attachment: { type: 'binary', string: 'Attachment' },
            avatar_128: { type: 'image', string: 'Avatar' },
            notes_html: { type: 'html', string: 'Notes' },
            priority: { type: 'priority', string: 'Priority' },
            signature: { type: 'signature', string: 'Signature' },
        });

        const sectionFields = schema.sections[0]?.fields ?? [];
        const fieldTypes = Object.fromEntries(sectionFields.map((field) => [field.name, field.type]));

        expect(schema.header.statusbar).toEqual({ field: 'state', visibleStates: [] });
        expect(fieldTypes).toEqual({
            name: 'char',
            description: 'text',
            sequence: 'integer',
            amount_total: 'float',
            credit_limit: 'monetary',
            is_company: 'boolean',
            customer_rank: 'selection',
            date_order: 'date',
            write_date: 'datetime',
            country_id: 'many2one',
            order_line: 'one2many',
            category_id: 'many2many',
            attachment: 'binary',
            avatar_128: 'image',
            notes_html: 'html',
            priority: 'priority',
            signature: 'signature',
        });
        expect(sectionFields.find((field) => field.name === 'credit_limit')).toEqual(
            expect.objectContaining({ currencyField: 'currency_id', digits: [16, 2] }),
        );
    });

    it('adds explicit onchange metadata only when the view declares it', () => {
        const service = new MobileSchemaBuilderService(new ConditionParserService());
        const xml = `
            <form string="Partners">
              <sheet>
                <group>
                  <field name="country_id" on_change="onchange_country_id(country_id, company_id)" />
                  <field name="name" />
                </group>
              </sheet>
            </form>
        `;

        const schema = service.build('res.partner', xml, {
            country_id: { type: 'many2one', string: 'Country', relation: 'res.country' },
            name: { type: 'char', string: 'Name' },
        });

        expect(schema.sections[0]?.fields).toEqual([
            expect.objectContaining({
                name: 'country_id',
                onchange: {
                    trigger: 'country_id',
                    source: 'view',
                    dependencies: ['company_id'],
                    mergeReturnedValue: true,
                },
            }),
            expect.objectContaining({
                name: 'name',
                onchange: undefined,
            }),
        ]);
    });

    it('normalizes unsupported Odoo field types into safe mobile fallbacks', () => {
        const service = new MobileSchemaBuilderService(new ConditionParserService());
        const xml = `
      <form string="Partners">
        <sheet>
        <group>
          <field name="x_custom_payload" />
                    <field name="x_properties" />
                    <field name="x_reference" />
                    <field name="x_many2one_reference" />
        </group>
        </sheet>
      </form>
    `;

        const schema = service.build('res.partner', xml, {
            x_custom_payload: { type: 'json', string: 'Custom Payload' },
            x_properties: { type: 'properties', string: 'Properties' },
            x_reference: { type: 'reference', string: 'Reference' },
            x_many2one_reference: { type: 'many2one_reference', string: 'Many2One Reference' },
        });

        expect(schema.sections).toEqual([
            {
                label: null,
                fields: [
                    expect.objectContaining({ name: 'x_custom_payload', type: 'text' }),
                    expect.objectContaining({ name: 'x_properties', type: 'text' }),
                    expect.objectContaining({ name: 'x_reference', type: 'text' }),
                    expect.objectContaining({ name: 'x_many2one_reference', type: 'text' }),
                ],
            },
        ]);
    });

    it('maps a narrow Odoo form XML into the mobile schema contract', () => {
        const service = new MobileSchemaBuilderService(new ConditionParserService());
        const xml = `
            <form string="Partners">
              <header>
                <button name="archive" string="Archive" type="object" class="btn-primary" invisible="state == 'done'" states="draft,confirm" />
                <field name="state" widget="statusbar" statusbar_visible="draft,done" />
              </header>
              <sheet invisible="company_type == 'private'">
                <group string="Main">
                  <field name="name" />
                  <field name="email" widget="email" readonly="state == 'done'" />
                </group>
                <notebook>
                  <page string="Contacts">
                    <group>
                      <field name="child_ids" />
                    </group>
                  </page>
                </notebook>
                <chatter class="oe_chatter" />
              </sheet>
            </form>
        `;

        const schema = service.build('res.partner', xml, {
            state: { type: 'selection', string: 'Status', selection: [['draft', 'Draft'], ['done', 'Done']] },
            name: { type: 'char', string: 'Name', required: true },
            email: { type: 'char', string: 'Email' },
            child_ids: { type: 'one2many', string: 'Contacts', relation: 'res.partner' },
        });

        expect(schema.title).toBe('Partners');
        expect(schema.header.statusbar).toEqual({ field: 'state', visibleStates: ['draft', 'done'] });
        expect(schema.header.actions).toEqual([
            {
                name: 'archive',
                label: 'Archive',
                type: 'object',
                style: 'primary',
                invisible: undefined,
                modifiers: {
                    invisible: {
                        type: 'or',
                        rules: [
                            { type: 'condition', condition: { field: 'state', op: '==', value: 'done' } },
                            { type: 'condition', condition: { field: 'state', op: 'not in', values: ['draft', 'confirm'] } },
                        ],
                    },
                },
                confirm: undefined,
            },
        ]);
        expect(schema.sections).toEqual([
            {
                label: 'Main',
                fields: [
                    expect.objectContaining({
                        name: 'name',
                        type: 'char',
                        label: 'Name',
                        required: true,
                        modifiers: {
                            invisible: {
                                type: 'condition',
                                condition: { field: 'company_type', op: '==', value: 'private' },
                            },
                            required: { type: 'constant', constant: true },
                        },
                    }),
                    expect.objectContaining({
                        name: 'email',
                        type: 'char',
                        label: 'Email',
                        widget: 'email',
                        readonly: undefined,
                        modifiers: {
                            invisible: {
                                type: 'condition',
                                condition: { field: 'company_type', op: '==', value: 'private' },
                            },
                            readonly: {
                                type: 'condition',
                                condition: { field: 'state', op: '==', value: 'done' },
                            },
                        },
                    }),
                ],
            },
        ]);
        expect(schema.tabs).toEqual([
            {
                label: 'Contacts',
                content: {
                    sections: [
                        {
                            label: null,
                            fields: [expect.objectContaining({ name: 'child_ids', comodel: 'res.partner' })],
                        },
                    ],
                },
            },
        ]);
        expect(schema.hasChatter).toBe(true);
    });
});