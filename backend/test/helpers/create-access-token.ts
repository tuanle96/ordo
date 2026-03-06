import type { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';

import type { TokenPayload } from '@ordo/shared';

export async function createAccessToken(
    app: INestApplication,
    payload: TokenPayload,
): Promise<string> {
    const jwtService = app.get(JwtService);
    const configService = app.get(ConfigService);

    return jwtService.signAsync(payload, {
        secret: configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
    });
}