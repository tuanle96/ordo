import {
    BadGatewayException,
    Injectable,
    UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';

import type { AuthUser, AuthenticatedPrincipal, TokenPayload, TokenResponse } from '@ordo/shared';

import { AdapterFactoryService } from '../../odoo/adapters/adapter-factory.service';
import { OdooRpcService } from '../../odoo/rpc/odoo-rpc.service';
import { OdooSessionStoreService } from '../../odoo/session/odoo-session-store.service';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
    constructor(
        private readonly configService: ConfigService,
        private readonly jwtService: JwtService,
        private readonly odooRpcService: OdooRpcService,
        private readonly adapterFactoryService: AdapterFactoryService,
        private readonly sessionStore: OdooSessionStoreService,
    ) { }

    async login(input: LoginDto): Promise<TokenResponse> {
        const version = await this.odooRpcService.detectVersion(input.odooUrl);
        this.adapterFactoryService.getAdapter(version.majorVersion);

        const upstreamSession = await this.odooRpcService.authenticateSession({
            odooUrl: input.odooUrl,
            db: input.db,
            login: input.login,
            password: input.password,
        });

        const user = await this.odooRpcService.readCurrentUserWithSession({
            odooUrl: input.odooUrl,
            cookieHeader: upstreamSession.cookieHeader,
        }, upstreamSession.uid);

        const storedSession = this.sessionStore.create({
            odooUrl: this.odooRpcService.normalizeBaseUrl(input.odooUrl),
            db: input.db,
            uid: upstreamSession.uid,
            version: version.majorVersion,
            lang: user.lang,
            cookieHeader: upstreamSession.cookieHeader,
        });

        const payload: TokenPayload = {
            uid: upstreamSession.uid,
            db: input.db,
            odooUrl: this.odooRpcService.normalizeBaseUrl(input.odooUrl),
            version: version.majorVersion,
            lang: user.lang,
            groups: user.groups,
            name: user.name,
            email: this.normalizeOptionalString(user.email),
            tz: this.normalizeOptionalString(user.tz),
            sessionHandle: storedSession.handle,
        };

        const accessExpiresIn = this.configService.get<number>(
            'JWT_ACCESS_EXPIRES_IN_SECONDS',
            900,
        );
        const refreshExpiresIn = this.configService.get<number>(
            'JWT_REFRESH_EXPIRES_IN_SECONDS',
            604800,
        );

        const accessToken = await this.jwtService.signAsync(payload, {
            secret: this.configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
            expiresIn: accessExpiresIn,
        });
        const refreshToken = await this.jwtService.signAsync(payload, {
            secret: this.configService.getOrThrow<string>('JWT_REFRESH_SECRET'),
            expiresIn: refreshExpiresIn,
        });

        return {
            accessToken,
            refreshToken,
            expiresIn: accessExpiresIn,
            user: this.toAuthUser(user),
        };
    }

    getAuthenticatedPrincipal(payload: TokenPayload): AuthenticatedPrincipal {
        const { sessionHandle: _sessionHandle, ...principal } = payload;
        return principal;
    }

    private toAuthUser(user: OdooUserProfile): AuthUser {
        if (!user.id || !user.name) {
            throw new BadGatewayException('Authenticated Odoo user profile is incomplete');
        }

        return {
            id: user.id,
            name: user.name,
            email: this.normalizeOptionalString(user.email),
            lang: user.lang,
            tz: this.normalizeOptionalString(user.tz),
        };
    }

    private normalizeOptionalString(
        value: string | false | null | undefined,
    ): string | undefined {
        return typeof value === 'string' && value.trim().length > 0 ? value : undefined;
    }
}

interface OdooUserProfile {
    id: number;
    name: string;
    email?: string | false | null;
    lang: string;
    tz?: string | false | null;
    groups: number[];
}