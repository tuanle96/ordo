import { NestFactory } from '@nestjs/core';

import { PinoLoggerService } from './common/logging/pino-logger.service';
import { AppModule } from './app.module';
import { configureHttpApp } from './app.factory';

async function bootstrap() {
    const app = await NestFactory.create(AppModule, { bufferLogs: true });
    const port = Number(process.env.PORT ?? 3000);

    configureHttpApp(app);
    app.useLogger(app.get(PinoLoggerService));

    await app.listen(port);
}

void bootstrap();