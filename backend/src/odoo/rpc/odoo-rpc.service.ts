import {
    BadGatewayException,
    Injectable,
    ServiceUnavailableException,
    UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import type {
    DetectedOdooVersion,
    OdooCallKwRequest,
    OdooCurrentUserProfile,
    OdooCurrentUserRequest,
    OdooExecuteKwRequest,
    OdooRpcAuthRequest,
    OdooVersionInfo,
} from './odoo-rpc.types';
import type { OdooAuthenticatedSession } from '../session/odoo-session.types';

@Injectable()
export class OdooRpcService {
    constructor(private readonly configService: ConfigService) { }

    normalizeBaseUrl(odooUrl: string): string {
        return new URL(odooUrl).toString().replace(/\/$/, '');
    }

    async detectVersion(odooUrl: string): Promise<DetectedOdooVersion> {
        const version = await this.postJsonRoute<OdooVersionInfo>(
            this.normalizeBaseUrl(odooUrl),
            '/web/webclient/version_info',
            {},
        );

        const major =
            Array.isArray(version.server_version_info) && version.server_version_info[0] !== undefined
                ? String(version.server_version_info[0])
                : '';
        if (!['17', '18', '19'].includes(major)) {
            throw new BadGatewayException(`Unsupported Odoo version: ${major || 'unknown'}`);
        }

        return {
            majorVersion: major,
            raw: version,
        };
    }

    async authenticate(input: OdooRpcAuthRequest): Promise<number> {
        const uid = await this.callService<number | false>(input.odooUrl, 'common', 'authenticate', [
            input.db,
            input.login,
            input.password,
            {},
        ]);

        if (!uid) {
            throw new UnauthorizedException('Wrong login/password');
        }

        return uid;
    }

    async authenticateSession(input: OdooRpcAuthRequest): Promise<OdooAuthenticatedSession> {
        const { payload, response } = await this.postJsonRouteWithResponse<{
            uid: number | null;
            user_context?: { lang?: string };
        }>(this.normalizeBaseUrl(input.odooUrl), '/web/session/authenticate', {
            db: input.db,
            login: input.login,
            password: input.password,
        });

        const sessionCookie = this.extractSessionCookie(response);
        const uid = payload.uid ?? undefined;

        if (!uid || !sessionCookie) {
            throw new UnauthorizedException('Wrong login/password');
        }

        return {
            uid,
            cookieHeader: sessionCookie,
            lang: payload.user_context?.lang ?? 'en_US',
        };
    }

    async readCurrentUser(input: OdooCurrentUserRequest) {
        const users = await this.readCurrentUserRecords(() => this.executeKw<OdooCurrentUserProfile[]>(input.odooUrl, {
            db: input.db,
            uid: input.uid,
            password: input.password,
            model: 'res.users',
            method: 'read',
            args: [[input.uid]],
            kwargs: {
                fields: ['id', 'name', 'email', 'lang', 'tz', 'groups_id'],
            },
        }), () => this.executeKw<OdooCurrentUserProfile[]>(input.odooUrl, {
            db: input.db,
            uid: input.uid,
            password: input.password,
            model: 'res.users',
            method: 'read',
            args: [[input.uid]],
            kwargs: {
                fields: ['id', 'name', 'email', 'lang', 'tz', 'group_ids'],
            },
        }));

        return this.mapCurrentUser(users);
    }

    async readCurrentUserWithSession(
        session: Pick<OdooCallKwRequest['session'], 'odooUrl' | 'cookieHeader'>,
        uid: number,
    ) {
        const users = await this.readCurrentUserRecords(() => this.callKwWithSession<OdooCurrentUserProfile[]>({
            session,
            model: 'res.users',
            method: 'read',
            args: [[uid]],
            kwargs: {
                fields: ['id', 'name', 'email', 'lang', 'tz', 'groups_id'],
            },
        }), () => this.callKwWithSession<OdooCurrentUserProfile[]>({
            session,
            model: 'res.users',
            method: 'read',
            args: [[uid]],
            kwargs: {
                fields: ['id', 'name', 'email', 'lang', 'tz', 'group_ids'],
            },
        }));

        return this.mapCurrentUser(users);
    }

    async executeKw<T>(odooUrl: string, request: OdooExecuteKwRequest): Promise<T> {
        return this.callService<T>(odooUrl, 'object', 'execute_kw', [
            request.db,
            request.uid,
            request.password,
            request.model,
            request.method,
            request.args ?? [],
            request.kwargs ?? {},
        ]);
    }

    async callKwWithSession<T>(request: OdooCallKwRequest): Promise<T> {
        return this.postJsonRoute<T>(this.normalizeBaseUrl(request.session.odooUrl), '/web/dataset/call_kw', {
            model: request.model,
            method: request.method,
            args: request.args ?? [],
            kwargs: request.kwargs ?? {},
        }, request.session.cookieHeader);
    }

    private async callService<T>(
        odooUrl: string,
        service: string,
        method: string,
        args: unknown[],
    ): Promise<T> {
        return this.postJsonRoute<T>(this.normalizeBaseUrl(odooUrl), '/jsonrpc', {
            service,
            method,
            args,
        });
    }

    private async postJsonRoute<T>(
        baseUrl: string,
        path: string,
        params: Record<string, unknown>,
        cookieHeader?: string,
    ): Promise<T> {
        const { payload } = await this.postJsonRouteWithResponse<T>(baseUrl, path, params, cookieHeader);

        return payload;
    }

    private async postJsonRouteWithResponse<T>(
        baseUrl: string,
        path: string,
        params: Record<string, unknown>,
        cookieHeader?: string,
    ): Promise<{ payload: T; response: Response }> {
        const response = await this.fetchWithTimeout(new URL(path, `${baseUrl}/`).toString(), {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                ...(cookieHeader ? { Cookie: cookieHeader } : {}),
            },
            body: JSON.stringify({
                jsonrpc: '2.0',
                method: 'call',
                params,
                id: Date.now(),
            }),
        });

        if (!response.ok) {
            throw new BadGatewayException(`Odoo upstream request failed with status ${response.status}`);
        }

        const payload = (await response.json()) as OdooJsonRpcEnvelope<T>;
        if (payload.error) {
            throw this.mapOdooError(payload.error);
        }

        if (payload.result === undefined) {
            throw new BadGatewayException('Odoo upstream response did not contain a result');
        }

        return {
            payload: payload.result,
            response,
        };
    }

    private async fetchWithTimeout(input: string, init: RequestInit): Promise<Response> {
        try {
            return await fetch(input, {
                ...init,
                signal: AbortSignal.timeout(
                    this.configService.get<number>('ODOO_REQUEST_TIMEOUT_MS', 15000),
                ),
            });
        } catch (error) {
            throw new ServiceUnavailableException(
                `Unable to reach Odoo upstream: ${error instanceof Error ? error.message : 'unknown error'}`,
            );
        }
    }

    private mapOdooError(error: OdooJsonRpcError): UnauthorizedException | BadGatewayException {
        const message = this.extractUpstreamMessage(error);

        if (message.toLowerCase().includes('accessdenied')) {
            return new UnauthorizedException('Wrong login/password');
        }

        return new BadGatewayException('Odoo upstream request failed');
    }

    private extractUpstreamMessage(error: OdooJsonRpcError): string {
        return (
            error.data?.message ??
            error.data?.name ??
            error.message ??
            'Unknown Odoo upstream error'
        );
    }

    private extractSessionCookie(response: Response): string | null {
        const rawCookie = response.headers.get('set-cookie');
        if (!rawCookie) {
            return null;
        }

        const match = rawCookie.match(/session_id=([^;]+)/);
        return match ? `session_id=${match[1]}` : null;
    }

    private async readCurrentUserRecords(
        primary: () => Promise<OdooCurrentUserProfile[]>,
        fallback: () => Promise<OdooCurrentUserProfile[]>,
    ): Promise<OdooCurrentUserProfile[]> {
        try {
            return await primary();
        } catch (error) {
            if (!(error instanceof BadGatewayException)) {
                throw error;
            }

            return fallback();
        }
    }

    private mapCurrentUser(users: OdooCurrentUserProfile[]) {
        const [user] = users;
        if (!user) {
            throw new BadGatewayException('Unable to load authenticated user profile from Odoo');
        }

        return {
            id: user.id,
            name: user.name,
            email: user.email,
            lang: user.lang ?? 'en_US',
            tz: user.tz,
            groups: user.groups_id ?? user.group_ids ?? [],
        };
    }
}

interface OdooJsonRpcEnvelope<T> {
    jsonrpc: string;
    id: number | string | null;
    result?: T;
    error?: OdooJsonRpcError;
}

interface OdooJsonRpcError {
    code: number;
    message: string;
    data?: {
        message?: string;
        debug?: string;
        name?: string;
    };
}