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
} from '@app/shared';

import { ConditionParserService } from '@app/odoo/schema/condition-parser.service';

@Injectable()
export class MobileSchemaBuilderService {
    private readonly layoutContainerKeys = ['div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'span', 'p'] as const;

    private readonly preGroupFieldTypes = new Set<FieldSchema['type']>([
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
        'html',
        'priority',
        'signature',
    ]);

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
            tabs: this.buildTabs(this.findNotebook(form.sheet ?? form), fieldsMeta, inheritedInvisible),
            hasChatter:
                form.chatter !== undefined ||
                form.sheet?.chatter !== undefined ||
                this.hasOeChatterDiv(form),
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
            const fields = this.deduplicateFields(this.collectFields(container, fieldsMeta, containerInvisible));
            return fields.length > 0 ? [{ label: null, fields }] : [];
        }

        const ungroupedFields = this.deduplicateFields(
            this.collectUngroupedFields(container, fieldsMeta, containerInvisible)
                .filter((field) => this.preGroupFieldTypes.has(field.type)),
        );

        const groupedSections = groups
            .map((group) => ({
                label: group['@_string'] ? String(group['@_string']) : null,
                fields: this.collectFields(group, fieldsMeta, containerInvisible),
            }))
            .filter((section) => section.fields.length > 0);

        return [
            ...(ungroupedFields.length > 0 ? [{ label: null, fields: ungroupedFields }] : []),
            ...groupedSections,
        ];
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
        const layoutFields = this.collectNestedContainerFields(container, fieldsMeta, inheritedInvisible, false);
        const nestedFields = this.asArray(container?.group).flatMap((group) => this.collectFields(group, fieldsMeta, this.mergeRules('or', inheritedInvisible, this.nodeInvisibleRule(group))));
        return [...directFields, ...layoutFields, ...nestedFields].filter((field): field is FieldSchema => Boolean(field));
    }

    private collectUngroupedFields(
        container: XmlNode | undefined,
        fieldsMeta: Record<string, OdooFieldMeta>,
        inheritedInvisible?: ConditionRule,
    ): FieldSchema[] {
        const directFields = this.asArray(container?.field).map((field) => this.toFieldSchema(field, fieldsMeta, inheritedInvisible));
        const layoutFields = this.collectNestedContainerFields(container, fieldsMeta, inheritedInvisible, true);
        return [...directFields, ...layoutFields].filter((field): field is FieldSchema => Boolean(field));
    }

    private collectNestedContainerFields(
        container: XmlNode | undefined,
        fieldsMeta: Record<string, OdooFieldMeta>,
        inheritedInvisible: ConditionRule | undefined,
        excludeGroups: boolean,
    ): FieldSchema[] {
        return this.childContainers(container).flatMap((child) => {
            const childInvisible = this.mergeRules('or', inheritedInvisible, this.nodeInvisibleRule(child));
            return excludeGroups
                ? this.collectUngroupedFields(child, fieldsMeta, childInvisible)
                : this.collectFields(child, fieldsMeta, childInvisible);
        });
    }

    private deduplicateFields(fields: FieldSchema[]): FieldSchema[] {
        const merged = new Map<string, FieldSchema>();
        for (const field of fields) {
            const existing = merged.get(field.name);
            if (!existing) {
                merged.set(field.name, field);
                continue;
            }

            // When a field appears multiple times (e.g. res.partner "name" with
            // mutually exclusive invisible conditions), merge the instances:
            //   - invisible: AND (field is hidden only when ALL instances are hidden)
            //   - readonly:  prefer editable (false) if either instance is editable
            //   - required:  prefer required (true) if either instance requires it
            const mergedInvisible = this.mergeRules('and', existing.modifiers?.invisible, field.modifiers?.invisible);
            const mergedReadonly = this.mergeModifierBoolean(existing.readonly, field.readonly, false);
            const mergedRequired = this.mergeModifierBoolean(existing.required, field.required, true);

            const mergedModifiers: FieldModifiers = {
                invisible: mergedInvisible,
                readonly: existing.modifiers?.readonly ?? field.modifiers?.readonly,
                required: existing.modifiers?.required ?? field.modifiers?.required,
            };

            merged.set(field.name, {
                ...existing,
                readonly: mergedReadonly,
                required: mergedRequired,
                invisible: this.extractSingleCondition(mergedInvisible),
                modifiers: this.compactModifiers(mergedModifiers),
            });
        }

        return Array.from(merged.values());
    }

    /** Merge two boolean modifier values: pick the "dominant" value when they differ. */
    private mergeModifierBoolean(a?: boolean, b?: boolean, dominant: boolean = false): boolean | undefined {
        if (a === dominant || b === dominant) return dominant;
        return a ?? b;
    }

    private childContainers(container: XmlNode | undefined): XmlNode[] {
        return this.layoutContainerKeys.flatMap((key) => this.asArray(container?.[key]));
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
            filenameField: this.extractFilenameField(fieldNode, meta, fieldsMeta),
            digits: meta.digits,
            subfields: subfields.length > 0 ? subfields : undefined,
            searchable: meta.type === 'many2one' || meta.type === 'many2many',
            widget: fieldNode['@_widget'],
        };
    }

    private extractFilenameField(
        fieldNode: XmlNode,
        meta: OdooFieldMeta,
        fieldsMeta: Record<string, OdooFieldMeta>,
    ): string | undefined {
        if (this.normalizeFieldType(meta.type, fieldNode['@_widget']) !== 'binary') {
            return undefined;
        }

        const filenameField = this.firstNonEmptyString(fieldNode['@_filename']);
        if (!filenameField) {
            return undefined;
        }

        return fieldsMeta[filenameField] ? filenameField : undefined;
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

    /**
     * Walk the XML tree depth-first looking for the first `<notebook>` node.
     * Odoo forms usually place `<notebook>` directly under `<sheet>`, but some
     * models (especially settings forms or heavily inherited views) may nest it
     * inside `<div>`, `<group>`, or other wrapper elements.
     */
    private findNotebook(container: XmlNode | undefined, depth = 0): XmlNode | undefined {
        if (!container || depth > 10) {
            return undefined;
        }

        if (container.notebook !== undefined) {
            return container.notebook;
        }

        for (const key of this.layoutContainerKeys) {
            for (const child of this.asArray(container[key])) {
                const found = this.findNotebook(child, depth + 1);
                if (found) {
                    return found;
                }
            }
        }

        for (const group of this.asArray(container.group)) {
            const found = this.findNotebook(group, depth + 1);
            if (found) {
                return found;
            }
        }

        return undefined;
    }

    /** Detect Odoo 17 chatter pattern: <div class="oe_chatter"> placed after </sheet>. */
    private hasOeChatterDiv(form: XmlNode): boolean {
        const divs = this.asArray(form.div).concat(this.asArray(form.sheet?.div));
        return divs.some(
            (div) => typeof div?.['@_class'] === 'string' && div['@_class'].includes('oe_chatter'),
        );
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