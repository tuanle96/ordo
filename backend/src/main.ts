import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';

import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { AppModule } from './app.module';

async function bootstrap() {
    const app = await NestFactory.create(AppModule);
    const prefix = process.env.API_PREFIX ?? 'api/v1/mobile';
    const port = Number(process.env.PORT ?? 3000);

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

    await app.listen(port);
}

void bootstrap();