import { Injectable } from '@nestjs/common';
import { XMLParser } from 'fast-xml-parser';

import type { ActionButton, FieldSchema, FormSection, FormTab, MobileFormSchema } from '@ordo/shared';

import { ConditionParserService } from './condition-parser.service';

@Injectable()
export class MobileSchemaBuilderService {
    private readonly parser = new XMLParser({
        ignoreAttributes: false,
        attributeNamePrefix: '@_',
        parseAttributeValue: false,
        trimValues: true,
    });

    constructor(private readonly conditionParser: ConditionParserService) { }

    build(model: string, viewArch: string, fieldsMeta: Record<string, OdooFieldMeta>): MobileFormSchema {
        const parsed = this.parser.parse(viewArch) as { form?: XmlNode };
        const form = parsed.form ?? {};

        return {
            model,
            title: String(form['@_string'] ?? model),
            header: this.buildHeader(form.header, fieldsMeta),
            sections: this.buildSections(form.sheet ?? form, fieldsMeta),
            tabs: this.buildTabs(form.sheet?.notebook ?? form.notebook, fieldsMeta),
            hasChatter: Boolean(form.chatter ?? form.sheet?.chatter),
        };
    }

    private buildHeader(header: XmlNode | undefined, fieldsMeta: Record<string, OdooFieldMeta>) {
        const actions: ActionButton[] = this.asArray(header?.button).map((button) => ({
            name: String(button['@_name'] ?? ''),
            label: String(button['@_string'] ?? button['@_name'] ?? ''),
            type: button['@_type'] === 'action' ? 'action' : 'object',
            style: button['@_class']?.includes('danger')
                ? 'danger'
                : button['@_class']?.includes('primary')
                    ? 'primary'
                    : 'secondary',
            invisible: this.conditionParser.parseInvisible(button['@_invisible']),
            confirm: button['@_confirm'],
        }));

        const statusField = this.asArray(header?.field).find((field) => field['@_widget'] === 'statusbar');
        const statusMeta = statusField ? fieldsMeta[String(statusField['@_name'])] : undefined;

        return {
            statusbar: statusField
                ? {
                    field: String(statusField['@_name']),
                    visibleStates: String(statusField['@_statusbar_visible'] ?? '')
                        .split(',')
                        .map((state) => state.trim())
                        .filter(Boolean),
                }
                : undefined,
            actions,
            ...(statusMeta ? {} : {}),
        };
    }

    private buildSections(container: XmlNode | undefined, fieldsMeta: Record<string, OdooFieldMeta>): FormSection[] {
        const groups = this.asArray(container?.group);
        if (groups.length === 0) {
            const fields = this.collectFields(container, fieldsMeta);
            return fields.length > 0 ? [{ label: null, fields }] : [];
        }

        return groups
            .map((group) => ({
                label: group['@_string'] ? String(group['@_string']) : null,
                fields: this.collectFields(group, fieldsMeta),
            }))
            .filter((section) => section.fields.length > 0);
    }

    private buildTabs(notebook: XmlNode | undefined, fieldsMeta: Record<string, OdooFieldMeta>): FormTab[] {
        return this.asArray(notebook?.page).map((page) => ({
            label: String(page['@_string'] ?? 'Tab'),
            content: {
                sections: this.buildSections(page, fieldsMeta),
            },
        }));
    }

    private collectFields(container: XmlNode | undefined, fieldsMeta: Record<string, OdooFieldMeta>): FieldSchema[] {
        const directFields = this.asArray(container?.field).map((field) => this.toFieldSchema(field, fieldsMeta));
        const nestedFields = this.asArray(container?.group).flatMap((group) => this.collectFields(group, fieldsMeta));
        return [...directFields, ...nestedFields].filter((field): field is FieldSchema => Boolean(field));
    }

    private toFieldSchema(fieldNode: XmlNode, fieldsMeta: Record<string, OdooFieldMeta>): FieldSchema | null {
        const name = String(fieldNode['@_name'] ?? '');
        if (!name) {
            return null;
        }

        const meta = fieldsMeta[name];
        if (!meta) {
            return null;
        }

        const subfields = this.asArray(fieldNode.list?.field).map((child) => this.toFieldSchema(child, fieldsMeta)).filter(Boolean) as FieldSchema[];

        return {
            name,
            type: fieldNode['@_widget'] === 'statusbar' ? 'statusbar' : meta.type,
            label: String(fieldNode['@_string'] ?? meta.string ?? name),
            required: Boolean(meta.required),
            readonly: Boolean(meta.readonly) || fieldNode['@_readonly'] === '1',
            invisible: this.conditionParser.parseInvisible(fieldNode['@_invisible']),
            domain: typeof fieldNode['@_domain'] === 'string' ? fieldNode['@_domain'] : meta.domain,
            comodel: meta.relation,
            selection: meta.selection,
            currencyField: meta.currency_field,
            digits: meta.digits,
            subfields: subfields.length > 0 ? subfields : undefined,
            searchable: meta.type === 'many2one' || meta.type === 'many2many',
            widget: fieldNode['@_widget'],
        };
    }

    private asArray<T>(value: T | T[] | undefined): T[] {
        if (value === undefined) {
            return [];
        }

        return Array.isArray(value) ? value : [value];
    }
}

type XmlNode = Record<string, any>;

interface OdooFieldMeta {
    string?: string;
    type: FieldSchema['type'];
    readonly?: boolean;
    required?: boolean;
    relation?: string;
    selection?: [string, string][];
    domain?: string;
    digits?: [number, number];
    currency_field?: string;
}