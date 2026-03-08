import { Injectable } from '@nestjs/common';
import { XMLParser } from 'fast-xml-parser';

import type {
    ActionButton,
    Condition,
    ConditionRule,
    FieldModifiers,
    OnchangeFieldMeta,
    FieldSchema,
    FormSection,
    FormTab,
    MobileFormSchema,
} from '@ordo/shared';

import { ConditionParserService } from './condition-parser.service';

@Injectable()
export class MobileSchemaBuilderService {
    private readonly supportedFieldTypes = new Set<FieldSchema['type']>([
        'char',
        'text',
        'integer',
        'float',
        'boolean',
        'selection',
        'date',
        'datetime',
        'many2one',
        'one2many',
        'many2many',
        'monetary',
        'binary',
        'image',
        'html',
        'statusbar',
        'priority',
        'signature',
    ]);

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
        const inheritedInvisible = this.nodeInvisibleRule(form);

        return {
            model,
            title: String(form['@_string'] ?? model),
            header: this.buildHeader(form.header, fieldsMeta),
            sections: this.buildSections(form.sheet ?? form, fieldsMeta, inheritedInvisible),
            tabs: this.buildTabs(form.sheet?.notebook ?? form.notebook, fieldsMeta, inheritedInvisible),
            hasChatter: Boolean(form.chatter ?? form.sheet?.chatter),
        };
    }

    private buildHeader(header: XmlNode | undefined, fieldsMeta: Record<string, OdooFieldMeta>) {
        const actions: ActionButton[] = this.asArray(header?.button).map((button) => {
            const invisibleRule = this.mergeRules('or', this.nodeInvisibleRule(button), this.conditionParser.parseStates(button['@_states']));

            return {
                name: String(button['@_name'] ?? ''),
                label: String(button['@_string'] ?? button['@_name'] ?? ''),
                type: button['@_type'] === 'action' ? 'action' : 'object',
                style: button['@_class']?.includes('danger')
                    ? 'danger'
                    : button['@_class']?.includes('primary')
                        ? 'primary'
                        : 'secondary',
                invisible: this.extractSingleCondition(invisibleRule),
                modifiers: invisibleRule ? { invisible: invisibleRule } : undefined,
                confirm: button['@_confirm'],
            };
        });

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

    private buildSections(
        container: XmlNode | undefined,
        fieldsMeta: Record<string, OdooFieldMeta>,
        inheritedInvisible?: ConditionRule,
    ): FormSection[] {
        const containerInvisible = this.mergeRules('or', inheritedInvisible, this.nodeInvisibleRule(container));
        const groups = this.asArray(container?.group);
        if (groups.length === 0) {
            const fields = this.collectFields(container, fieldsMeta, containerInvisible);
            return fields.length > 0 ? [{ label: null, fields }] : [];
        }

        return groups
            .map((group) => ({
                label: group['@_string'] ? String(group['@_string']) : null,
                fields: this.collectFields(group, fieldsMeta, containerInvisible),
            }))
            .filter((section) => section.fields.length > 0);
    }

    private buildTabs(
        notebook: XmlNode | undefined,
        fieldsMeta: Record<string, OdooFieldMeta>,
        inheritedInvisible?: ConditionRule,
    ): FormTab[] {
        return this.asArray(notebook?.page).map((page) => ({
            label: String(page['@_string'] ?? 'Tab'),
            content: {
                sections: this.buildSections(
                    page,
                    fieldsMeta,
                    this.mergeRules('or', inheritedInvisible, this.nodeInvisibleRule(page), this.conditionParser.parseStates(page['@_states'])),
                ),
            },
        }));
    }

    private collectFields(
        container: XmlNode | undefined,
        fieldsMeta: Record<string, OdooFieldMeta>,
        inheritedInvisible?: ConditionRule,
    ): FieldSchema[] {
        const directFields = this.asArray(container?.field).map((field) => this.toFieldSchema(field, fieldsMeta, inheritedInvisible));
        const nestedFields = this.asArray(container?.group).flatMap((group) => this.collectFields(group, fieldsMeta, this.mergeRules('or', inheritedInvisible, this.nodeInvisibleRule(group))));
        return [...directFields, ...nestedFields].filter((field): field is FieldSchema => Boolean(field));
    }

    private toFieldSchema(
        fieldNode: XmlNode,
        fieldsMeta: Record<string, OdooFieldMeta>,
        inheritedInvisible?: ConditionRule,
    ): FieldSchema | null {
        const name = String(fieldNode['@_name'] ?? '');
        if (!name) {
            return null;
        }

        const meta = fieldsMeta[name];
        if (!meta) {
            return null;
        }

        const modifiers = this.buildFieldModifiers(fieldNode, meta, inheritedInvisible);
        const subfields = this.asArray(fieldNode.list?.field)
            .map((child) => this.toFieldSchema(child, fieldsMeta, modifiers.invisible))
            .filter(Boolean) as FieldSchema[];

        return {
            name,
            type: this.normalizeFieldType(meta.type, fieldNode['@_widget']),
            label: String(fieldNode['@_string'] ?? meta.string ?? name),
            required: this.staticBoolean(modifiers.required),
            readonly: this.staticBoolean(modifiers.readonly),
            invisible: this.extractSingleCondition(modifiers.invisible),
            modifiers: this.compactModifiers(modifiers),
            onchange: this.buildOnchangeMeta(fieldNode),
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

    private buildFieldModifiers(
        fieldNode: XmlNode,
        meta: OdooFieldMeta,
        inheritedInvisible?: ConditionRule,
    ): FieldModifiers {
        return {
            invisible: this.mergeRules(
                'or',
                inheritedInvisible,
                this.nodeInvisibleRule(fieldNode),
                this.conditionParser.parseStates(fieldNode['@_states']),
            ),
            readonly: this.ruleFromAttribute(fieldNode['@_readonly'], meta.readonly),
            required: this.ruleFromAttribute(fieldNode['@_required'], meta.required),
        };
    }

    private nodeInvisibleRule(node?: XmlNode): ConditionRule | undefined {
        return typeof node?.['@_invisible'] === 'string'
            ? this.conditionParser.parseRule(node['@_invisible'])
            : undefined;
    }

    private ruleFromAttribute(raw: unknown, fallback?: boolean): ConditionRule | undefined {
        if (typeof raw === 'string' && raw.trim()) {
            return this.conditionParser.parseRule(raw.trim());
        }

        return fallback === undefined ? undefined : { type: 'constant', constant: fallback };
    }

    private mergeRules(type: 'and' | 'or', ...rules: Array<ConditionRule | undefined>): ConditionRule | undefined {
        const filtered = rules.filter((rule): rule is ConditionRule => Boolean(rule));
        if (filtered.length === 0) {
            return undefined;
        }

        if (filtered.length === 1) {
            return filtered[0];
        }

        return { type, rules: filtered };
    }

    private extractSingleCondition(rule?: ConditionRule): Condition | undefined {
        return rule?.type === 'condition' ? rule.condition : undefined;
    }

    private staticBoolean(rule?: ConditionRule): boolean | undefined {
        return rule?.type === 'constant' ? rule.constant : undefined;
    }

    private compactModifiers(modifiers: FieldModifiers): FieldModifiers | undefined {
        return modifiers.invisible || modifiers.readonly || modifiers.required
            ? modifiers
            : undefined;
    }

    private buildOnchangeMeta(fieldNode: XmlNode): OnchangeFieldMeta | undefined {
        const trigger = String(fieldNode['@_name'] ?? '').trim();
        if (!trigger) {
            return undefined;
        }

        const rawOnchange = this.firstNonEmptyString(fieldNode['@_on_change'], fieldNode['@_onchange']);
        if (!rawOnchange) {
            return undefined;
        }

        return {
            trigger,
            source: 'view',
            dependencies: this.extractOnchangeDependencies(rawOnchange, trigger),
            mergeReturnedValue: true,
        };
    }

    private extractOnchangeDependencies(expression: string, trigger: string): string[] | undefined {
        const match = expression.match(/\(([^)]*)\)/);
        if (!match) {
            return undefined;
        }

        const dependencies = match[1]
            .split(',')
            .map((value) => value.trim())
            .filter((value) => this.isFieldIdentifier(value) && value !== trigger);

        return dependencies.length > 0 ? Array.from(new Set(dependencies)) : undefined;
    }

    private firstNonEmptyString(...values: unknown[]): string | undefined {
        for (const value of values) {
            if (typeof value === 'string' && value.trim()) {
                return value.trim();
            }
        }

        return undefined;
    }

    private isFieldIdentifier(value: string): boolean {
        return /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(value);
    }

    private normalizeFieldType(rawType: string, widget?: unknown): FieldSchema['type'] {
        if (widget === 'statusbar') {
            return 'statusbar';
        }

        if (this.supportedFieldTypes.has(rawType as FieldSchema['type'])) {
            return rawType as FieldSchema['type'];
        }

        // Odoo instances can expose addon/custom field types that the mobile client
        // does not model explicitly. Normalize them to a safe, read-only-capable type
        // so schema decoding does not fail the entire detail screen on iOS.
        switch (rawType) {
            case 'json':
            case 'properties':
            case 'reference':
            case 'many2one_reference':
                return 'text';
            default:
                return 'text';
        }
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
    type: string;
    readonly?: boolean;
    required?: boolean;
    relation?: string;
    selection?: [string, string][];
    domain?: string;
    digits?: [number, number];
    currency_field?: string;
}