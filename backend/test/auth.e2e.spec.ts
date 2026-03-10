import type { INestApplication } from '@nestjs/common';
import request from 'supertest';

import { AuthService } from '@app/modules/auth/auth.service';
import { odooFixtures } from '@test/fixtures/odoo.fixtures';
import { createAccessToken } from '@test/helpers/create-access-token';
import { createTestApp } from '@test/helpers/create-test-app';

describe('Auth endpoints', () => {
    let app: INestApplication;
    let protectedApp: INestApplication;
    let rateLimitedApp: INestApplication;
    let accessToken: string;
    const originalEnv = {
        CORS_ALLOWED_ORIGINS: process.env.CORS_ALLOWED_ORIGINS,
        AUTH_LOGIN_RATE_LIMIT: process.env.AUTH_LOGIN_RATE_LIMIT,
        AUTH_LOGIN_RATE_TTL_SECONDS: process.env.AUTH_LOGIN_RATE_TTL_SECONDS,
        AUTH_REFRESH_RATE_LIMIT: process.env.AUTH_REFRESH_RATE_LIMIT,
        AUTH_REFRESH_RATE_TTL_SECONDS: process.env.AUTH_REFRESH_RATE_TTL_SECONDS,
    };

    const authServiceMock = {
        login: jest.fn().mockResolvedValue(odooFixtures.tokenResponse),
        refresh: jest.fn().mockResolvedValue(odooFixtures.tokenResponse),
        logout: jest.fn().mockResolvedValue({ success: true }),
        getAuthenticatedPrincipal: jest.fn().mockReturnValue(odooFixtures.authenticatedPrincipal),
    };

    beforeAll(async () => {
        process.env.CORS_ALLOWED_ORIGINS = 'https://allowed.example.com';
        process.env.AUTH_LOGIN_RATE_LIMIT = '2';
        process.env.AUTH_LOGIN_RATE_TTL_SECONDS = '60';
        process.env.AUTH_REFRESH_RATE_LIMIT = '2';
        process.env.AUTH_REFRESH_RATE_TTL_SECONDS = '60';

        app = await createTestApp();
        protectedApp = await createTestApp([
            { token: AuthService, useValue: authServiceMock },
        ]);
        rateLimitedApp = await createTestApp([
            { token: AuthService, useValue: authServiceMock },
        ]);
        accessToken = await createAccessToken(protectedApp, odooFixtures.tokenPayload);
    });

    afterAll(async () => {
        await Promise.all([app.close(), protectedApp.close(), rateLimitedApp.close()]);
        Object.entries(originalEnv).forEach(([key, value]) => {
            if (value === undefined) {
                delete process.env[key];
                return;
            }

            process.env[key] = value;
        });
    });

    it('rejects /auth/me without a bearer token', async () => {
        await request(app.getHttpServer())
            .get('/api/v1/mobile/auth/me')
            .expect(401);
    });

    it('returns token response from /auth/login', async () => {
        const payload = {
            odooUrl: 'http://127.0.0.1:38421',
            db: 'odoo17',
            login: 'admin',
            password: 'admin',
        };

        const response = await request(protectedApp.getHttpServer())
            .post('/api/v1/mobile/auth/login')
            .send(payload)
            .expect(201);

        expect(authServiceMock.login).toHaveBeenCalledWith(expect.objectContaining(payload));
        expect(response.body.data).toEqual(odooFixtures.tokenResponse);
    });

    it('returns token response from /auth/refresh', async () => {
        const refreshToken = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOjF9.c2ln';

        const response = await request(protectedApp.getHttpServer())
            .post('/api/v1/mobile/auth/refresh')
            .send({ refreshToken })
            .expect(201);

        expect(authServiceMock.refresh).toHaveBeenCalledWith(
            expect.objectContaining({ refreshToken }),
        );
        expect(response.body.data).toEqual(odooFixtures.tokenResponse);
    });

    it('returns authenticated principal from /auth/me', async () => {
        const response = await request(protectedApp.getHttpServer())
            .get('/api/v1/mobile/auth/me')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(200);

        expect(authServiceMock.getAuthenticatedPrincipal).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2, sessionHandle: 'session-handle-123' }),
        );
        expect(response.body.data).toEqual(odooFixtures.authenticatedPrincipal);
    });

    it('returns success from /auth/logout', async () => {
        const response = await request(protectedApp.getHttpServer())
            .post('/api/v1/mobile/auth/logout')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(201);

        expect(authServiceMock.logout).toHaveBeenCalledWith(
            expect.objectContaining({ uid: 2, sessionHandle: 'session-handle-123' }),
        );
        expect(response.body.data).toEqual({ success: true });
    });

    it('throttles repeated login attempts on /auth/login', async () => {
        const payload = {
            odooUrl: 'http://127.0.0.1:38421',
            db: 'odoo17',
            login: 'admin',
            password: 'admin',
        };

        await request(rateLimitedApp.getHttpServer())
            .post('/api/v1/mobile/auth/login')
            .send(payload)
            .expect(201);

        await request(rateLimitedApp.getHttpServer())
            .post('/api/v1/mobile/auth/login')
            .send(payload)
            .expect(201);

        const response = await request(rateLimitedApp.getHttpServer())
            .post('/api/v1/mobile/auth/login')
            .send(payload)
            .expect(429);

        expect(response.body.errors[0]?.message).toContain('Too Many Requests');
    });

    it('throttles repeated refresh attempts on /auth/refresh', async () => {
        const payload = { refreshToken: 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOjF9.c2ln' };

        await request(rateLimitedApp.getHttpServer())
            .post('/api/v1/mobile/auth/refresh')
            .send(payload)
            .expect(201);

        await request(rateLimitedApp.getHttpServer())
            .post('/api/v1/mobile/auth/refresh')
            .send(payload)
            .expect(201);

        const response = await request(rateLimitedApp.getHttpServer())
            .post('/api/v1/mobile/auth/refresh')
            .send(payload)
            .expect(429);

        expect(response.body.errors[0]?.message).toContain('Too Many Requests');
    });

    it('allows configured CORS preflight origins and fails closed for unlisted origins', async () => {
        const allowedResponse = await request(app.getHttpServer())
            .options('/api/v1/mobile/auth/login')
            .set('Origin', 'https://allowed.example.com')
            .set('Access-Control-Request-Method', 'POST')
            .expect(204);

        expect(allowedResponse.headers['access-control-allow-origin']).toBe('https://allowed.example.com');

        const deniedResponse = await request(app.getHttpServer())
            .options('/api/v1/mobile/auth/login')
            .set('Origin', 'https://denied.example.com')
            .set('Access-Control-Request-Method', 'POST')
            .expect(404);

        expect(deniedResponse.headers['access-control-allow-origin']).toBeUndefined();
    });
});