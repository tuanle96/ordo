import { Module } from '@nestjs/common';

import { RedisModule } from '../common/redis/redis.module';
import { AdapterFactoryService } from './adapters/adapter-factory.service';
import { OdooV17Adapter } from './adapters/odoo-v17.adapter';
import { OdooV18Adapter } from './adapters/odoo-v18.adapter';
import { OdooV19Adapter } from './adapters/odoo-v19.adapter';
import { OdooRpcService } from './rpc/odoo-rpc.service';
import { ConditionParserService } from './schema/condition-parser.service';
import { MobileListSchemaBuilderService } from './schema/mobile-list-schema-builder.service';
import { MobileSchemaBuilderService } from './schema/mobile-schema-builder.service';
import { OdooSessionStoreService } from './session/odoo-session-store.service';

@Module({
    imports: [RedisModule],
    providers: [
        OdooRpcService,
        OdooSessionStoreService,
        ConditionParserService,
        MobileListSchemaBuilderService,
        MobileSchemaBuilderService,
        OdooV17Adapter,
        OdooV18Adapter,
        OdooV19Adapter,
        AdapterFactoryService,
    ],
    exports: [OdooRpcService, OdooSessionStoreService, AdapterFactoryService],
})
export class OdooModule { }