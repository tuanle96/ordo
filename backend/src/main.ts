import { NestFactory } from '@nestjs/core';

import { AppModule } from './app.module';
import { configureHttpApp } from './app.factory';

async function bootstrap() {
    const app = await NestFactory.create(AppModule);
    const port = Number(process.env.PORT ?? 3000);

    configureHttpApp(app);

    await app.listen(port);
}

void bootstrap();