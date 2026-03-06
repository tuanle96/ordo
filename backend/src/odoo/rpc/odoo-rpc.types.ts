import type { LoginRequest } from '@ordo/shared';

import type { OdooSessionContext } from '../session/odoo-session.types';

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
    email?: string;
    lang?: string;
    tz?: string;
    groups_id?: number[];
}