/**
 * Canonical mobile-safe field matrix shared across backend schema normalization
 * and iOS rendering/editing. New values here should only be added together with
 * backend normalization + client support, not as speculative Odoo type mirrors.
 */
export type FieldType =
    | 'char'
    | 'text'
    | 'integer'
    | 'float'
    | 'boolean'
    | 'selection'
    | 'date'
    | 'datetime'
    | 'many2one'
    | 'one2many'
    | 'many2many'
    | 'monetary'
    | 'binary'
    | 'image'
    | 'html'
    | 'statusbar'
    | 'priority'
    | 'signature';

export type ConditionValue = string | number | boolean | null;

export interface Condition {
    field: string;
    op: '==' | '!=' | 'in' | 'not in' | '>' | '<' | '>=' | '<=';
    value?: ConditionValue;
    values?: ConditionValue[];
}

export interface ConditionRule {
    type: 'condition' | 'and' | 'or' | 'not' | 'constant';
    condition?: Condition;
    rules?: ConditionRule[];
    constant?: boolean;
}

export interface FieldModifiers {
    invisible?: ConditionRule;
    readonly?: ConditionRule;
    required?: ConditionRule;
}

export interface OnchangeFieldMeta {
    trigger: string;
    source?: 'view' | 'spec';
    dependencies?: string[];
    mergeReturnedValue?: boolean;
}

export interface ActionButton {
    name: string;
    label: string;
    type: 'object' | 'action';
    style?: 'primary' | 'secondary' | 'danger';
    invisible?: Condition;
    modifiers?: Pick<FieldModifiers, 'invisible'>;
    confirm?: string;
}

export interface FieldSchema {
    name: string;
    type: FieldType;
    label: string;
    required?: boolean;
    readonly?: boolean;
    invisible?: Condition;
    modifiers?: FieldModifiers;
    onchange?: OnchangeFieldMeta;
    domain?: string;
    comodel?: string;
    selection?: [string, string][];
    /** Present for monetary fields when the record carries a related currency field. */
    currencyField?: string;
    /** Present for binary fields when Odoo exposes a companion filename field. */
    filenameField?: string;
    placeholder?: string;
    digits?: [number, number];
    subfields?: FieldSchema[];
    searchable?: boolean;
    widget?: string;
}

export interface FormHeader {
    statusbar?: {
        field: string;
        visibleStates?: string[];
    };
    actions: ActionButton[];
}

export interface FormSection {
    label: string | null;
    fields: FieldSchema[];
}

export interface FormTab {
    label: string;
    content: Record<string, unknown>;
}

export interface ListColumn {
    name: string;
    type: FieldType;
    label: string;
    comodel?: string;
    selection?: [string, string][];
    widget?: string;
    optional?: 'show' | 'hide';
    columnInvisible?: boolean;
}

export interface SearchFilter {
    name: string;
    label: string;
    /** JSON-encoded Odoo domain array suitable for the existing `domain` query transport. */
    domain: string;
}

export interface SearchGroupBy {
    name: string;
    label: string;
    fieldName: string;
}

export interface SearchField {
    name: string;
    label: string;
    type: FieldType;
    filterDomain?: string;
    selection?: [string, string][];
}

export interface KanbanCardField {
    name: string;
    type: FieldType;
    label: string;
    widget?: string;
    comodel?: string;
}

export interface KanbanCardButton {
    name: string;
    label: string;
    type: 'object' | 'action';
    style: 'primary' | 'secondary' | 'link';
    invisible?: ConditionRule;
}

export interface MobileKanbanSchema {
    model: string;
    title: string;
    groupByField?: string;
    groupBySelection?: [string, string][];
    cardFields: KanbanCardField[];
    cardButtons: KanbanCardButton[];
    colorField?: string;
    search: {
        fields: SearchField[];
        filters: SearchFilter[];
    };
}

export interface MobileListSchema {
    model: string;
    title: string;
    columns: ListColumn[];
    defaultOrder?: string;
    search: {
        fields: SearchField[];
        filters: SearchFilter[];
        groupBy: SearchGroupBy[];
    };
}

export interface MobileFormSchema {
    model: string;
    title: string;
    header: FormHeader;
    sections: FormSection[];
    tabs: FormTab[];
    hasChatter: boolean;
}
