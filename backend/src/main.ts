import { NestFactory } from '@nestjs/core';

import { PinoLoggerService } from '@app/common/logging/pino-logger.service';
import { configureHttpApp } from '@app/app.factory';
import { AppModule } from '@app/app.module';

async function bootstrap() {
    const app = await NestFactory.create(AppModule, { bufferLogs: true });
    const port = Number(process.env.PORT ?? 3000);

    configureHttpApp(app);
    app.useLogger(app.get(PinoLoggerService));

    await app.listen(port);
}

void bootstrap();