import { ValidationPipe } from '@nestjs/common';
import type { INestApplication } from '@nestjs/common';

import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';

export function configureHttpApp(app: INestApplication): void {
    const prefix = process.env.API_PREFIX ?? 'api/v1/mobile';

    // Keep /health unprefixed for local smoke checks and future infrastructure probes.
    app.setGlobalPrefix(prefix, { exclude: ['health'] });
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