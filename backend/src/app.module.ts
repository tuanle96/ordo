import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { resolve } from 'node:path';

import { validateEnvironment } from '@app/common/config/validate-environment';
import { PinoLoggerService } from '@app/common/logging/pino-logger.service';
import { RedisModule } from '@app/common/redis/redis.module';
import { AuthModule } from '@app/modules/auth/auth.module';
import { HealthModule } from '@app/modules/health/health.module';
import { ModuleModule } from '@app/modules/module/module.module';
import { RecordModule } from '@app/modules/record/record.module';
import { SchemaModule } from '@app/modules/schema/schema.module';
import { OdooModule } from '@app/odoo/odoo.module';

@Module({
    imports: [
        ConfigModule.forRoot({
            isGlobal: true,
            envFilePath: [resolve(__dirname, '../.env'), resolve(__dirname, '../../.env')],
            validate: validateEnvironment,
        }),
        ThrottlerModule.forRoot([
            {
                limit: 1000,
                ttl: 60_000,
            },
        ]),
        RedisModule,
        AuthModule,
        HealthModule,
        ModuleModule,
        SchemaModule,
        RecordModule,
        OdooModule,
    ],
    providers: [PinoLoggerService],
})
export class AppModule { }