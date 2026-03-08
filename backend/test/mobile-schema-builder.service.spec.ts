import { ConditionParserService } from '../src/odoo/schema/condition-parser.service';
import { MobileSchemaBuilderService } from '../src/odoo/schema/mobile-schema-builder.service';

describe('MobileSchemaBuilderService', () => {
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
        </group>
        </sheet>
      </form>
    `;

        const schema = service.build('res.partner', xml, {
            x_custom_payload: { type: 'json', string: 'Custom Payload' },
        });

        expect(schema.sections).toEqual([
            {
                label: null,
                fields: [expect.objectContaining({ name: 'x_custom_payload', type: 'text' })],
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