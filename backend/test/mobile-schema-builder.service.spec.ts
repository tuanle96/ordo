import { ConditionParserService } from '@app/odoo/schema/condition-parser.service';
import { MobileSchemaBuilderService } from '@app/odoo/schema/mobile-schema-builder.service';

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
                                    <field name="attachment" filename="attachment_name" />
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
            attachment_name: { type: 'char', string: 'Attachment Name' },
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
        expect(sectionFields.find((field) => field.name === 'attachment')).toEqual(
            expect.objectContaining({ filenameField: 'attachment_name' }),
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

    it('collects title-container name fields before grouped sections for partner forms', () => {
        const service = new MobileSchemaBuilderService(new ConditionParserService());
        const xml = `
            <form string="Partners">
              <sheet>
                <field name="avatar_128" invisible="1" />
                <field name="image_1920" widget="image" />
                <div class="oe_title">
                  <field name="is_company" invisible="1" />
                  <field name="company_type" widget="radio" />
                  <h1>
                    <field name="name" invisible="not is_company" required="type == 'contact'" />
                    <field name="name" invisible="is_company" required="type == 'contact'" />
                  </h1>
                </div>
                <group string="Contact">
                  <field name="phone" widget="phone" />
                </group>
              </sheet>
            </form>
        `;

        const schema = service.build('res.partner', xml, {
            avatar_128: { type: 'image', string: 'Avatar' },
            image_1920: { type: 'image', string: 'Image' },
            is_company: { type: 'boolean', string: 'Company' },
            company_type: { type: 'selection', string: 'Company Type', selection: [['company', 'Company'], ['person', 'Individual']] },
            name: { type: 'char', string: 'Name', required: true },
            phone: { type: 'char', string: 'Phone' },
        });

        expect(schema.sections).toHaveLength(2);
        expect(schema.sections[0]).toEqual({
            label: null,
            fields: [
                expect.objectContaining({
                    name: 'is_company',
                    type: 'boolean',
                    modifiers: { invisible: { type: 'constant', constant: true } },
                }),
                expect.objectContaining({ name: 'company_type', type: 'selection' }),
                expect.objectContaining({
                    name: 'name',
                    type: 'char',
                    modifiers: expect.objectContaining({
                        invisible: {
                            type: 'and',
                            rules: [
                                {
                                    type: 'not',
                                    rules: [
                                        {
                                            type: 'condition',
                                            condition: { field: 'is_company', op: '==', value: true },
                                        },
                                    ],
                                },
                                {
                                    type: 'condition',
                                    condition: { field: 'is_company', op: '==', value: true },
                                },
                            ],
                        },
                        required: {
                            type: 'condition',
                            condition: { field: 'type', op: '==', value: 'contact' },
                        },
                    }),
                }),
            ],
        });
        expect(schema.sections[1]).toEqual({
            label: 'Contact',
            fields: [expect.objectContaining({ name: 'phone', type: 'char', widget: 'phone' })],
        });
    });

    it('finds notebook nested inside a div container', () => {
        const service = new MobileSchemaBuilderService(new ConditionParserService());
        const xml = `
            <form string="Settings">
              <sheet>
                <group>
                  <field name="title" />
                </group>
                <div class="o_settings_container">
                  <notebook>
                    <page string="General">
                      <group>
                        <field name="option_a" />
                      </group>
                    </page>
                    <page string="Advanced">
                      <group>
                        <field name="option_b" />
                      </group>
                    </page>
                  </notebook>
                </div>
              </sheet>
            </form>
        `;

        const schema = service.build('res.config.settings', xml, {
            title: { type: 'char', string: 'Title' },
            option_a: { type: 'boolean', string: 'Option A' },
            option_b: { type: 'boolean', string: 'Option B' },
        });

        expect(schema.sections).toHaveLength(1);
        expect(schema.sections[0]?.fields).toEqual([
            expect.objectContaining({ name: 'title', type: 'char' }),
        ]);
        expect(schema.tabs).toHaveLength(2);
        expect(schema.tabs[0]).toEqual({
            label: 'General',
            content: {
                sections: [{ label: null, fields: [expect.objectContaining({ name: 'option_a' })] }],
            },
        });
        expect(schema.tabs[1]).toEqual({
            label: 'Advanced',
            content: {
                sections: [{ label: null, fields: [expect.objectContaining({ name: 'option_b' })] }],
            },
        });
    });

    it('parses a realistic res.users form with inherited tabs and additional fields', () => {
        const service = new MobileSchemaBuilderService(new ConditionParserService());
        // Simulates the combined arch after module inheritance (auth_totp, mail, etc.)
        const xml = `
            <form string="Users">
              <sheet>
                <field name="id" invisible="1" />
                <field name="image_1920" widget="image" />
                <div class="oe_title">
                  <h1><field name="name" required="1" /></h1>
                  <field name="email" invisible="1" />
                  <h2><field name="login" /></h2>
                </div>
                <field name="partner_id" invisible="1" />
                <group name="phone_numbers">
                  <field name="phone" widget="phone" />
                  <field name="mobile" widget="phone" />
                </group>
                <notebook>
                  <page string="Access Rights" name="access_rights">
                    <group string="User Type">
                      <field name="groups_id" />
                    </group>
                    <group string="Administration" invisible="share">
                      <field name="in_group_base_group_erp_manager" />
                    </group>
                    <group string="Extra Rights">
                      <field name="in_group_base_group_allow_export" />
                      <field name="in_group_base_group_multi_company" />
                    </group>
                  </page>
                  <page string="Preferences" name="preferences">
                    <group>
                      <field name="lang" />
                      <field name="tz" />
                      <field name="company_id" />
                    </group>
                    <group>
                      <field name="notification_type" />
                    </group>
                  </page>
                  <page string="Account Security" name="account_security">
                    <group>
                      <field name="totp_enabled" />
                    </group>
                  </page>
                </notebook>
              </sheet>
              <chatter />
            </form>
        `;

        const schema = service.build('res.users', xml, {
            id: { type: 'integer', string: 'ID', readonly: true },
            image_1920: { type: 'image', string: 'Image' },
            name: { type: 'char', string: 'Name', required: true },
            email: { type: 'char', string: 'Email' },
            login: { type: 'char', string: 'Login' },
            partner_id: { type: 'many2one', string: 'Related Partner', relation: 'res.partner' },
            phone: { type: 'char', string: 'Phone' },
            mobile: { type: 'char', string: 'Mobile' },
            groups_id: { type: 'many2many', string: 'Groups', relation: 'res.groups' },
            share: { type: 'boolean', string: 'Share User' },
            in_group_base_group_erp_manager: { type: 'boolean', string: 'Access to Export Feature' },
            in_group_base_group_allow_export: { type: 'boolean', string: 'Contact Creation' },
            in_group_base_group_multi_company: { type: 'boolean', string: 'Multi Companies' },
            lang: { type: 'selection', string: 'Language', selection: [['en_US', 'English (US)']] },
            tz: { type: 'selection', string: 'Timezone', selection: [['UTC', 'UTC']] },
            company_id: { type: 'many2one', string: 'Company', relation: 'res.company' },
            notification_type: { type: 'selection', string: 'Notification', selection: [['email', 'Email'], ['inbox', 'Inbox']] },
            totp_enabled: { type: 'boolean', string: 'Two-Factor Authentication' },
        });

        // Verify sections include the pre-group fields
        const allSectionFieldNames = schema.sections.flatMap((section) => section.fields.map((field) => field.name));
        expect(allSectionFieldNames).toContain('name');
        expect(allSectionFieldNames).toContain('login');
        expect(allSectionFieldNames).toContain('phone');
        expect(allSectionFieldNames).toContain('mobile');

        // Verify tabs are extracted correctly
        expect(schema.tabs).toHaveLength(3);
        expect(schema.tabs.map((tab) => tab.label)).toEqual(['Access Rights', 'Preferences', 'Account Security']);

        // Check Access Rights tab content
        const accessRightsTab = schema.tabs[0];
        const accessRightsSections = accessRightsTab.content.sections as Array<{ label: string | null; fields: Array<{ name: string }> }>;
        const accessRightsFieldNames = accessRightsSections.flatMap((section) => section.fields.map((field) => field.name));
        expect(accessRightsFieldNames).toContain('groups_id');
        expect(accessRightsFieldNames).toContain('in_group_base_group_erp_manager');

        // Check Preferences tab content
        const prefsTab = schema.tabs[1];
        const prefsSections = prefsTab.content.sections as Array<{ label: string | null; fields: Array<{ name: string }> }>;
        const prefsFieldNames = prefsSections.flatMap((section) => section.fields.map((field) => field.name));
        expect(prefsFieldNames).toContain('lang');
        expect(prefsFieldNames).toContain('tz');
        expect(prefsFieldNames).toContain('company_id');

        // Check chatter
        expect(schema.hasChatter).toBe(true);
    });

    it('detects Odoo 17 chatter declared as <div class="oe_chatter">', () => {
        const service = new MobileSchemaBuilderService(new ConditionParserService());
        const xml = `
            <form string="Partners">
              <sheet>
                <group>
                  <field name="name" />
                </group>
              </sheet>
              <div class="oe_chatter">
                <field name="message_follower_ids" />
                <field name="activity_ids" />
                <field name="message_ids" />
              </div>
            </form>
        `;

        const schema = service.build('res.partner', xml, {
            name: { type: 'char', string: 'Name' },
        });

        expect(schema.hasChatter).toBe(true);
    });
});