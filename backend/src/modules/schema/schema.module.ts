import { Module } from '@nestjs/common';

import { OdooModule } from '@app/odoo/odoo.module';
import { SchemaController } from '@app/modules/schema/schema.controller';
import { SchemaCacheService } from '@app/modules/schema/schema-cache.service';
import { SchemaService } from '@app/modules/schema/schema.service';

@Module({
    imports: [OdooModule],
    controllers: [SchemaController],
    providers: [SchemaCacheService, SchemaService],
})
export class SchemaModule { }