import type { LoginRequest, RecordData } from '@app/shared';

import type { OdooSessionContext } from '@app/odoo/session/odoo-session.types';

export interface OdooVersionInfo {
    server_version: string;
    server_version_info: Array<number | string>;
    server_serie: string;
    protocol_version: number;
}

export interface DetectedOdooVersion {
    majorVersion: string;
    raw: OdooVersionInfo;
}

export interface OdooRpcAuthRequest extends LoginRequest { }

export interface OdooExecuteKwRequest {
    db: string;
    uid: number;
    password: string;
    model: string;
    method: string;
    args?: unknown[];
    kwargs?: Record<string, unknown>;
}

export interface OdooCurrentUserRequest {
    odooUrl: string;
    db: string;
    uid: number;
    password: string;
}

export interface OdooCallKwRequest {
    session: Pick<OdooSessionContext, 'odooUrl' | 'cookieHeader'>;
    model: string;
    method: string;
    args?: unknown[];
    kwargs?: Record<string, unknown>;
}

export interface OdooCurrentUserProfile {
    id: number;
    name: string;
    email?: string | false | null;
    lang?: string;
    tz?: string | false | null;
    groups_id?: number[];
    group_ids?: number[];
}

export interface OdooFieldsSpec {
    [fieldName: string]: {
        fields?: OdooFieldsSpec;
    };
}

export interface OdooOnchangeWarning {
    title: string;
    message: string;
    type?: string;
    className?: string;
    sticky?: boolean;
}

export interface OdooOnchangeResponse {
    value?: RecordData;
    warning?: OdooOnchangeWarning | null;
    domain?: Record<string, unknown>;
}