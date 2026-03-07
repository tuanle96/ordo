import type { INestApplication } from '@nestjs/common';
import request from 'supertest';

import { AuthService } from '../src/modules/auth/auth.service';
import { odooFixtures } from './fixtures/odoo.fixtures';
import { createAccessToken } from './helpers/create-access-token';
import { createTestApp } from './helpers/create-test-app';

describe('Auth endpoints', () => {
    let app: INestApplication;
    let protectedApp: INestApplication;
    let accessToken: string;

    const authServiceMock = {
        login: jest.fn().mockResolvedValue(odooFixtures.tokenResponse),
        refresh: jest.fn().mockResolvedValue(odooFixtures.tokenResponse),
        getAuthenticatedPrincipal: jest.fn().mockReturnValue(odooFixtures.authenticatedPrincipal),
    };

    beforeAll(async () => {
        app = await createTestApp();
        protectedApp = await createTestApp([
            { token: AuthService, useValue: authServiceMock },
        ]);
        accessToken = await createAccessToken(protectedApp, odooFixtures.tokenPayload);
    });

    afterAll(async () => {
        await Promise.all([app.close(), protectedApp.close()]);
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
});