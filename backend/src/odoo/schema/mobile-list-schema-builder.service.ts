import { Injectable } from '@nestjs/common';
import { XMLParser } from 'fast-xml-parser';

import type {
    FieldType,
    ListColumn,
    MobileListSchema,
    SearchField,
    SearchFilter,
    SearchGroupBy,
} from '@app/shared';

import { ConditionParserService } from '@app/odoo/schema/condition-parser.service';

@Injectable()
export class MobileListSchemaBuilderService {
    private readonly supportedFieldTypes = new Set<FieldType>([
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

    build(
        model: string,
        treeArch: string,
        searchArch: string | undefined,
        fieldsMeta: Record<string, OdooFieldMeta>,
    ): MobileListSchema {
        const parsedTree = this.parser.parse(treeArch) as { tree?: XmlNode; list?: XmlNode };
        const tree = parsedTree.tree ?? parsedTree.list ?? {};
        const search = searchArch
            ? ((this.parser.parse(searchArch) as { search?: XmlNode }).search ?? {})
            : {};

        return {
            model,
            title: String(tree['@_string'] ?? model),
            columns: this.asArray(tree.field)
                .map((field) => this.toListColumn(field, fieldsMeta))
                .filter((field): field is ListColumn => Boolean(field)),
            defaultOrder: this.firstNonEmptyString(tree['@_default_order']),
            search: {
                fields: this.asArray(search.field)
                    .map((field) => this.toSearchField(field, fieldsMeta))
                    .filter((field): field is SearchField => Boolean(field)),
                filters: this.collectSearchFilters(search),
                groupBy: this.collectGroupByFilters(search),
            },
        };
    }

    private collectSearchFilters(search: XmlNode): SearchFilter[] {
        return this.asArray(search.filter)
            .map((filter) => this.toSearchFilter(filter))
            .filter((filter): filter is SearchFilter => Boolean(filter));
    }

    private collectGroupByFilters(search: XmlNode): SearchGroupBy[] {
        const nestedFilters = this.asArray(search.group).flatMap((group) => this.asArray(group.filter));
        const filters = [...this.asArray(search.filter), ...nestedFilters];
        const seen = new Set<string>();

        return filters
            .map((filter) => this.toSearchGroupBy(filter))
            .filter((filter): filter is SearchGroupBy => Boolean(filter))
            .filter((filter) => {
                const key = `${filter.name}:${filter.fieldName}`;
                if (seen.has(key)) {
                    return false;
                }

                seen.add(key);
                return true;
            });
    }

    private toListColumn(fieldNode: XmlNode, fieldsMeta: Record<string, OdooFieldMeta>): ListColumn | null {
        const name = this.firstNonEmptyString(fieldNode['@_name']);
        if (!name) {
            return null;
        }

        const meta = fieldsMeta[name];
        if (!meta) {
            return null;
        }

        const optional = fieldNode['@_optional'] === 'show' || fieldNode['@_optional'] === 'hide'
            ? fieldNode['@_optional']
            : undefined;

        return {
            name,
            type: this.normalizeFieldType(meta.type, fieldNode['@_widget']),
            label: String(fieldNode['@_string'] ?? meta.string ?? name),
            comodel: meta.relation,
            selection: meta.selection,
            widget: this.firstNonEmptyString(fieldNode['@_widget']),
            optional,
            columnInvisible: this.attributeIsTruthy(fieldNode['@_column_invisible']) || undefined,
        };
    }

    private toSearchField(fieldNode: XmlNode, fieldsMeta: Record<string, OdooFieldMeta>): SearchField | null {
        const name = this.firstNonEmptyString(fieldNode['@_name']);
        if (!name) {
            return null;
        }

        const meta = fieldsMeta[name];
        if (!meta) {
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
        if (!domain) {
            return null;
        }

        const label = this.firstNonEmptyString(filterNode['@_string'], filterNode['@_name']);
        if (!label) {
            return null;
        }

        return {
            name: this.firstNonEmptyString(filterNode['@_name']) ?? this.slugify(label),
            label,
            domain,
        };
    }

    private toSearchGroupBy(filterNode: XmlNode): SearchGroupBy | null {
        const fieldName = this.extractGroupByField(filterNode['@_context']);
        if (!fieldName) {
            return null;
        }

        const label = this.firstNonEmptyString(filterNode['@_string'], filterNode['@_name'], fieldName) ?? fieldName;

        return {
            name: this.firstNonEmptyString(filterNode['@_name']) ?? this.slugify(label),
            label,
            fieldName,
        };
    }

    private serializeDomain(rawDomain: unknown): string | undefined {
        if (typeof rawDomain !== 'string' || !rawDomain.trim()) {
            return undefined;
        }

        const parsed = this.conditionParser.parsePythonValue(rawDomain);
        return Array.isArray(parsed) ? JSON.stringify(parsed) : undefined;
    }

    private extractGroupByField(rawContext: unknown): string | undefined {
        if (typeof rawContext !== 'string' || !rawContext.trim()) {
            return undefined;
        }

        const singleMatch = rawContext.match(/['\"]group_by['\"]\s*:\s*['\"]([^'\"]+)['\"]/);
        if (singleMatch?.[1]) {
            return singleMatch[1].trim();
        }

        const listMatch = rawContext.match(/['\"]group_by['\"]\s*:\s*\[([^\]]+)\]/);
        if (!listMatch?.[1]) {
            return undefined;
        }

        const fieldMatch = listMatch[1].match(/['\"]([^'\"]+)['\"]/);
        return fieldMatch?.[1]?.trim();
    }

    private attributeIsTruthy(value: unknown): boolean {
        if (typeof value !== 'string') {
            return false;
        }

        const normalized = value.trim().toLowerCase();
        if (!normalized) {
            return false;
        }

        return !['0', 'false', 'none'].includes(normalized);
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

        if (this.supportedFieldTypes.has(rawType as FieldType)) {
            return rawType as FieldType;
        }

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

    private firstNonEmptyString(...values: unknown[]): string | undefined {
        for (const value of values) {
            if (typeof value === 'string' && value.trim()) {
                return value.trim();
            }
        }

        return undefined;
    }

    private slugify(value: string): string {
        return value
            .trim()
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '_')
            .replace(/^_+|_+$/g, '') || 'filter';
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
    relation?: string;
    selection?: [string, string][];
}