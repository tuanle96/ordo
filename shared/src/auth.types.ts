export interface LoginRequest {
    odooUrl: string;
    db: string;
    login: string;
    password: string;
}

export interface RefreshTokenRequest {
    refreshToken: string;
}

export interface AuthUser {
    id: number;
    name: string;
    email?: string;
    lang: string;
    tz?: string;
    avatarUrl?: string;
}

export interface TokenPayload {
    uid: number;
    db: string;
    odooUrl: string;
    version: string;
    lang: string;
    groups: number[];
    name: string;
    email?: string;
    tz?: string;
    sessionHandle: string;
    iat?: number;
    exp?: number;
}

export type AuthenticatedPrincipal = Omit<TokenPayload, 'sessionHandle'>;

export interface TokenResponse {
    accessToken: string;
    refreshToken: string;
    expiresIn: number;
    user: AuthUser;
}

export interface LogoutResponse {
    success: true;
}