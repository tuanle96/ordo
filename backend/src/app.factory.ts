import { ValidationPipe } from '@nestjs/common';
import type { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { NestExpressApplication } from '@nestjs/platform-express';

import { HttpExceptionFilter } from '@app/common/filters/http-exception.filter';
import { TransformInterceptor } from '@app/common/interceptors/transform.interceptor';
import { createHttpLogger } from '@app/common/logging/pino.config';
import { PinoLoggerService } from '@app/common/logging/pino-logger.service';

export function configureHttpApp(app: INestApplication): void {
    const configService = app.get(ConfigService);
    const prefix = configService.get<string>('API_PREFIX', 'api/v1/mobile');
    const nodeEnv = configService.get<string>('NODE_ENV', 'development');
    const corsAllowedOrigins = parseAllowedOrigins(configService.get<string>('CORS_ALLOWED_ORIGINS'));
    const mobileJsonBodyLimitBytes = Number(process.env.MOBILE_JSON_BODY_LIMIT_BYTES ?? 3_000_000);
    const expressApp = app as INestApplication & Pick<NestExpressApplication, 'useBodyParser'>;

    // Keep /health unprefixed for local smoke checks and future infrastructure probes.
    expressApp.useBodyParser('json', { limit: mobileJsonBodyLimitBytes });
    expressApp.useBodyParser('urlencoded', { limit: mobileJsonBodyLimitBytes, extended: true });
    app.setGlobalPrefix(prefix, { exclude: ['health'] });
    app.useLogger(app.get(PinoLoggerService));
    app.use(createHttpLogger(configService));
    app.enableCors({
        origin: (
            origin: string | undefined,
            callback: (error: Error | null, allow?: boolean) => void,
        ) => {
            if (!origin) {
                callback(null, true);
                return;
            }

            if (isAllowedOrigin(origin, corsAllowedOrigins, nodeEnv)) {
                callback(null, true);
                return;
            }

            callback(null, false);
        },
        methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
        allowedHeaders: ['Content-Type', 'Authorization'],
        optionsSuccessStatus: 204,
    });
    app.useGlobalPipes(
        new ValidationPipe({
            whitelist: true,
            transform: true,
            forbidNonWhitelisted: true,
        }),
    );
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new TransformInterceptor());
}

function parseAllowedOrigins(rawOrigins?: string): string[] {
    if (!rawOrigins) {
        return [];
    }

    return rawOrigins
        .split(',')
        .map((origin) => origin.trim())
        .filter((origin) => origin.length > 0);
}

function isAllowedOrigin(origin: string, allowlist: string[], nodeEnv: string): boolean {
    if (allowlist.includes(origin)) {
        return true;
    }

    const isLocalDevelopment = nodeEnv === 'development' || nodeEnv === 'test';
    if (!isLocalDevelopment) {
        return false;
    }

    return /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(origin);
}