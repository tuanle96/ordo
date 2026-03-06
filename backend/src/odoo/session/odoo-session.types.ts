export interface OdooSessionContext {
    handle: string;
    odooUrl: string;
    db: string;
    uid: number;
    version: string;
    lang: string;
    cookieHeader: string;
    expiresAt: number;
}

export interface OdooAuthenticatedSession {
    uid: number;
    cookieHeader: string;
    lang: string;
}