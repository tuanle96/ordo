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

export interface Condition {
    field: string;
    op: '==' | '!=' | 'in' | 'not in' | '>' | '<' | '>=' | '<=';
    value?: string;
    values?: string[];
}

export interface ActionButton {
    name: string;
    label: string;
    type: 'object' | 'action';
    style?: 'primary' | 'secondary' | 'danger';
    invisible?: Condition;
    confirm?: string;
}

export interface FieldSchema {
    name: string;
    type: FieldType;
    label: string;
    required?: boolean;
    readonly?: boolean;
    invisible?: Condition;
    domain?: string;
    comodel?: string;
    selection?: [string, string][];
    currencyField?: string;
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

export interface MobileFormSchema {
    model: string;
    title: string;
    header: FormHeader;
    sections: FormSection[];
    tabs: FormTab[];
    hasChatter: boolean;
}