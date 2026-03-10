import { Module } from '@nestjs/common';

import { RedisModule } from '@app/common/redis/redis.module';
import { AdapterFactoryService } from '@app/odoo/adapters/adapter-factory.service';
import { OdooV17Adapter } from '@app/odoo/adapters/odoo-v17.adapter';
import { OdooV18Adapter } from '@app/odoo/adapters/odoo-v18.adapter';
import { OdooV19Adapter } from '@app/odoo/adapters/odoo-v19.adapter';
import { OdooRpcService } from '@app/odoo/rpc/odoo-rpc.service';
import { ConditionParserService } from '@app/odoo/schema/condition-parser.service';
import { MobileListSchemaBuilderService } from '@app/odoo/schema/mobile-list-schema-builder.service';
import { MobileSchemaBuilderService } from '@app/odoo/schema/mobile-schema-builder.service';
import { OdooSessionStoreService } from '@app/odoo/session/odoo-session-store.service';

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