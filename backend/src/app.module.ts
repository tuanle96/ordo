import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { resolve } from 'node:path';

import { validateEnvironment } from './common/config/validate-environment';
import { AuthModule } from './modules/auth/auth.module';
import { HealthModule } from './modules/health/health.module';
import { RecordModule } from './modules/record/record.module';
import { SchemaModule } from './modules/schema/schema.module';
import { OdooModule } from './odoo/odoo.module';

@Module({
    imports: [
        ConfigModule.forRoot({
            isGlobal: true,
            envFilePath: [resolve(__dirname, '../.env'), resolve(__dirname, '../../.env')],
            validate: validateEnvironment,
        }),
        AuthModule,
        HealthModule,
        SchemaModule,
        RecordModule,
        OdooModule,
    ],
})
export class AppModule { }