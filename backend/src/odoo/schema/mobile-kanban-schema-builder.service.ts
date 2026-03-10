import { Injectable } from '@nestjs/common';
import { XMLParser } from 'fast-xml-parser';

import type {
    ConditionRule,
    FieldType,
    KanbanCardButton,
    KanbanCardField,
    MobileKanbanSchema,
    SearchField,
    SearchFilter,
} from '@app/shared';

import { ConditionParserService } from '@app/odoo/schema/condition-parser.service';

@Injectable()
export class MobileKanbanSchemaBuilderService {
    private readonly parser = new XMLParser({
        ignoreAttributes: false,
        attributeNamePrefix: '@_',
        parseAttributeValue: false,
        trimValues: true,
    });

    constructor(private readonly conditionParser: ConditionParserService) { }

    build(
        model: string,
        kanbanArch: string,
        searchArch: string | undefined,
        fieldsMeta: Record<string, OdooFieldMeta>,
    ): MobileKanbanSchema | null {
        const kanban = ((this.parser.parse(kanbanArch) as { kanban?: XmlNode }).kanban ?? {});
        const search = searchArch
            ? ((this.parser.parse(searchArch) as { search?: XmlNode }).search ?? {})
            : {};
        const groupByField = this.firstNonEmptyString(kanban['@_default_group_by']);
        const groupMeta = groupByField ? fieldsMeta[groupByField] : undefined;

        const fieldNodes = new Map<string, XmlNode>();
        this.collectFieldNodes(kanban, fieldNodes);

        const buttonNodes: XmlNode[] = [];
        this.collectButtonNodes(kanban, buttonNodes);

        const cardFieldNames = this.orderedUnique([
            ...fieldNodes.keys(),
            ...['display_name', 'name'].filter((fieldName) => fieldsMeta[fieldName]),
        ]).filter((fieldName) => fieldName !== groupByField);
        const cardFields = cardFieldNames
            .map((fieldName) => this.toKanbanCardField(fieldName, fieldNodes.get(fieldName), fieldsMeta))
            .filter((field): field is KanbanCardField => Boolean(field));
        if (cardFields.length === 0) {
            return null;
        }

        const cardButtons = buttonNodes
            .map((buttonNode) => this.toKanbanCardButton(buttonNode))
            .filter((button): button is KanbanCardButton => Boolean(button));

        return {
            model,
            title: String(kanban['@_string'] ?? model),
            groupByField,
            groupBySelection: groupMeta?.selection,
            cardFields,
            cardButtons,
            colorField: this.firstNonEmptyString(kanban['@_highlight_color'], kanban['@_color']),
            search: {
                fields: this.asArray(search.field)
                    .map((field) => this.toSearchField(field, fieldsMeta))
                    .filter((field): field is SearchField => Boolean(field)),
                filters: this.asArray(search.filter)
                    .map((filter) => this.toSearchFilter(filter))
                    .filter((filter): filter is SearchFilter => Boolean(filter)),
            },
        };
    }

    private collectFieldNodes(node: unknown, target: Map<string, XmlNode>): void {
        if (!node || typeof node !== 'object') {
            return;
        }

        if (Array.isArray(node)) {
            node.forEach((item) => this.collectFieldNodes(item, target));
            return;
        }

        const xmlNode = node as XmlNode;
        for (const fieldNode of this.asArray(xmlNode.field)) {
            const name = this.firstNonEmptyString(fieldNode?.['@_name']);
            if (name && !target.has(name)) {
                target.set(name, fieldNode);
            }
        }

        for (const [key, value] of Object.entries(xmlNode)) {
            if (key === 'field' || key === 'button') {
                continue;
            }

            this.collectFieldNodes(value, target);
        }
    }

    private collectButtonNodes(node: unknown, target: XmlNode[], seen: Set<string> = new Set()): void {
        if (!node || typeof node !== 'object') {
            return;
        }

        if (Array.isArray(node)) {
            node.forEach((item) => this.collectButtonNodes(item, target, seen));
            return;
        }

        const xmlNode = node as XmlNode;
        for (const buttonNode of this.asArray(xmlNode.button)) {
            const name = this.firstNonEmptyString(buttonNode?.['@_name']);
            if (name && buttonNode?.['@_type'] === 'object' && !seen.has(name)) {
                seen.add(name);
                target.push(buttonNode);
            }
        }

        for (const [key, value] of Object.entries(xmlNode)) {
            if (key === 'button') {
                continue;
            }

            this.collectButtonNodes(value, target, seen);
        }
    }

    private toKanbanCardField(
        name: string,
        fieldNode: XmlNode | undefined,
        fieldsMeta: Record<string, OdooFieldMeta>,
    ): KanbanCardField | null {
        const meta = fieldsMeta[name];
        if (!meta) {
            return null;
        }

        return {
            name,
            type: this.normalizeFieldType(meta.type, fieldNode?.['@_widget']),
            label: String(fieldNode?.['@_string'] ?? meta.string ?? name),
            widget: this.firstNonEmptyString(fieldNode?.['@_widget']),
            comodel: meta.relation,
        };
    }

    private toKanbanCardButton(buttonNode: XmlNode): KanbanCardButton | null {
        const name = this.firstNonEmptyString(buttonNode['@_name']);
        if (!name) {
            return null;
        }

        const label = String(buttonNode['@_string'] ?? buttonNode['#text'] ?? name);
        const cssClass = String(buttonNode['@_class'] ?? '');
        const invisibleRule = this.parseInvisibleRule(buttonNode);

        return {
            name,
            label,
            type: 'object',
            style: cssClass.includes('primary') ? 'primary' : 'secondary',
            invisible: invisibleRule,
        };
    }

    private parseInvisibleRule(node: XmlNode): ConditionRule | undefined {
        const raw = node['@_invisible'];
        return typeof raw === 'string' && raw.trim()
            ? this.conditionParser.parseRule(raw.trim())
            : undefined;
    }

    private toSearchField(fieldNode: XmlNode, fieldsMeta: Record<string, OdooFieldMeta>): SearchField | null {
        const name = this.firstNonEmptyString(fieldNode['@_name']);
        const meta = name ? fieldsMeta[name] : undefined;
        if (!name || !meta) {
            return null;
        }

        return {
            name,
            label: String(fieldNode['@_string'] ?? meta.string ?? name),
            type: this.normalizeFieldType(meta.type, fieldNode['@_widget']),
            filterDomain: this.serializeDomain(fieldNode['@_filter_domain']),
            selection: meta.selection,
        };
    }

    private toSearchFilter(filterNode: XmlNode): SearchFilter | null {
        const domain = this.serializeDomain(filterNode['@_domain']);
        const label = this.firstNonEmptyString(filterNode['@_string'], filterNode['@_name']);
        if (!domain || !label) {
            return null;
        }

        return {
            name: this.firstNonEmptyString(filterNode['@_name']) ?? this.slugify(label),
            label,
            domain,
        };
    }

    private serializeDomain(rawDomain: unknown): string | undefined {
        if (typeof rawDomain !== 'string' || !rawDomain.trim()) {
            return undefined;
        }

        const parsed = this.conditionParser.parsePythonValue(rawDomain);
        return Array.isArray(parsed) ? JSON.stringify(parsed) : undefined;
    }

    private normalizeFieldType(rawType: string, widget?: unknown): FieldType {
        if (widget === 'statusbar') {
            return 'statusbar';
        }

        if (widget === 'priority') {
            return 'priority';
        }

        if (typeof widget === 'string' && widget.includes('image')) {
            return 'image';
        }

        const normalizedType = rawType as FieldType;
        if (SUPPORTED_FIELD_TYPES.has(normalizedType)) {
            return normalizedType;
        }

        return 'text';
    }

    private firstNonEmptyString(...values: unknown[]): string | undefined {
        for (const value of values) {
            if (typeof value === 'string' && value.trim()) {
                return value.trim();
            }
        }

        return undefined;
    }

    private slugify(value: string): string {
        return value.trim().toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '') || 'filter';
    }

    private orderedUnique(values: string[]): string[] {
        const seen = new Set<string>();
        return values.filter((value) => seen.has(value) ? false : seen.add(value));
    }

    private asArray<T>(value: T | T[] | undefined): T[] {
        if (value === undefined) {
            return [];
        }

        return Array.isArray(value) ? value : [value];
    }
}

const SUPPORTED_FIELD_TYPES = new Set<FieldType>([
    'char', 'text', 'integer', 'float', 'boolean', 'selection', 'date', 'datetime', 'many2one', 'one2many',
    'many2many', 'monetary', 'binary', 'image', 'html', 'statusbar', 'priority', 'signature',
]);

type XmlNode = Record<string, any>;

interface OdooFieldMeta {
    string?: string;
    type: string;
    relation?: string;
    selection?: [string, string][];
}