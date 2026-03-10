import { ConditionParserService } from '@app/odoo/schema/condition-parser.service';
import { MobileListSchemaBuilderService } from '@app/odoo/schema/mobile-list-schema-builder.service';

describe('MobileListSchemaBuilderService', () => {
    it('maps a tree view into ordered list columns with widgets and visibility flags', () => {
        const service = new MobileListSchemaBuilderService(new ConditionParserService());
        const treeXml = `
            <tree string="Partners" default_order="name asc">
                <field name="name" />
                <field name="email" optional="hide" />
                <field name="customer_rank" widget="priority" />
                <field name="image_128" widget="image" column_invisible="1" />
            </tree>
        `;

        const schema = service.build('res.partner', treeXml, '<search />', {
            name: { type: 'char', string: 'Name' },
            email: { type: 'char', string: 'Email' },
            customer_rank: { type: 'selection', string: 'Rank', selection: [['0', 'Normal'], ['1', 'VIP']] },
            image_128: { type: 'binary', string: 'Avatar' },
        });

        expect(schema.title).toBe('Partners');
        expect(schema.defaultOrder).toBe('name asc');
        expect(schema.columns).toEqual([
            { name: 'name', type: 'char', label: 'Name', widget: undefined, optional: undefined, columnInvisible: undefined, comodel: undefined, selection: undefined },
            { name: 'email', type: 'char', label: 'Email', widget: undefined, optional: 'hide', columnInvisible: undefined, comodel: undefined, selection: undefined },
            { name: 'customer_rank', type: 'priority', label: 'Rank', widget: 'priority', optional: undefined, columnInvisible: undefined, comodel: undefined, selection: [['0', 'Normal'], ['1', 'VIP']] },
            { name: 'image_128', type: 'image', label: 'Avatar', widget: 'image', optional: undefined, columnInvisible: true, comodel: undefined, selection: undefined },
        ]);
    });

    it('maps search fields, domain filters, and group-by filters from search XML', () => {
        const service = new MobileListSchemaBuilderService(new ConditionParserService());
        const searchXml = `
            <search string="Search Partners">
                <field name="name" filter_domain="[('name','ilike',self)]" />
                <field name="is_company" />
                <filter name="type_company" string="Companies" domain="[('is_company','=',True)]" />
                <group string="Group By">
                    <filter name="group_country" string="Country" context="{'group_by': 'country_id'}" />
                </group>
            </search>
        `;

        const schema = service.build('res.partner', '<tree><field name="name" /></tree>', searchXml, {
            name: { type: 'char', string: 'Name' },
            is_company: { type: 'boolean', string: 'Company' },
            country_id: { type: 'many2one', string: 'Country', relation: 'res.country' },
        });

        expect(schema.search.fields).toEqual([
            { name: 'name', label: 'Name', type: 'char', filterDomain: '[["name","ilike","self"]]', selection: undefined },
            { name: 'is_company', label: 'Company', type: 'boolean', filterDomain: undefined, selection: undefined },
        ]);
        expect(schema.search.filters).toEqual([
            { name: 'type_company', label: 'Companies', domain: '[["is_company","=",true]]' },
        ]);
        expect(schema.search.groupBy).toEqual([
            { name: 'group_country', label: 'Country', fieldName: 'country_id' },
        ]);
    });

    it('handles real-ish partner tree and search snippets without per-model hardcoding', () => {
        const service = new MobileListSchemaBuilderService(new ConditionParserService());
        const treeXml = `
            <tree string="Contacts" default_order="display_name asc">
                <field name="display_name" />
                <field name="email" optional="show" />
                <field name="phone" optional="hide" />
                <field name="country_id" />
            </tree>
        `;
        const searchXml = `
            <search string="Search Contacts">
                <field name="display_name" filter_domain="['|', ('display_name','ilike',self), ('name','ilike',self)]" />
                <field name="email" />
                <filter name="companies" string="Companies" domain="[('is_company','=',True)]" />
                <filter name="people" string="Individuals" domain="[('is_company','=',False)]" />
                <group string="Group By">
                    <filter name="group_salesperson" string="Salesperson" context="{'group_by': 'user_id'}" />
                </group>
            </search>
        `;

        const schema = service.build('res.partner', treeXml, searchXml, {
            display_name: { type: 'char', string: 'Name' },
            name: { type: 'char', string: 'Legal Name' },
            email: { type: 'char', string: 'Email' },
            phone: { type: 'char', string: 'Phone' },
            country_id: { type: 'many2one', string: 'Country', relation: 'res.country' },
            is_company: { type: 'boolean', string: 'Company' },
            user_id: { type: 'many2one', string: 'Salesperson', relation: 'res.users' },
        });

        expect(schema).toEqual({
            model: 'res.partner',
            title: 'Contacts',
            defaultOrder: 'display_name asc',
            columns: [
                { name: 'display_name', type: 'char', label: 'Name', comodel: undefined, selection: undefined, widget: undefined, optional: undefined, columnInvisible: undefined },
                { name: 'email', type: 'char', label: 'Email', comodel: undefined, selection: undefined, widget: undefined, optional: 'show', columnInvisible: undefined },
                { name: 'phone', type: 'char', label: 'Phone', comodel: undefined, selection: undefined, widget: undefined, optional: 'hide', columnInvisible: undefined },
                { name: 'country_id', type: 'many2one', label: 'Country', comodel: 'res.country', selection: undefined, widget: undefined, optional: undefined, columnInvisible: undefined },
            ],
            search: {
                fields: [
                    { name: 'display_name', label: 'Name', type: 'char', filterDomain: '["|",["display_name","ilike","self"],["name","ilike","self"]]', selection: undefined },
                    { name: 'email', label: 'Email', type: 'char', filterDomain: undefined, selection: undefined },
                ],
                filters: [
                    { name: 'companies', label: 'Companies', domain: '[["is_company","=",true]]' },
                    { name: 'people', label: 'Individuals', domain: '[["is_company","=",false]]' },
                ],
                groupBy: [
                    { name: 'group_salesperson', label: 'Salesperson', fieldName: 'user_id' },
                ],
            },
        });
    });
});