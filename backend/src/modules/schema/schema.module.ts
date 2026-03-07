import { Module } from '@nestjs/common';

import { OdooModule } from '../../odoo/odoo.module';
import { SchemaController } from './schema.controller';
import { SchemaCacheService } from './schema-cache.service';
import { SchemaService } from './schema.service';

@Module({
    imports: [OdooModule],
    controllers: [SchemaController],
    providers: [SchemaCacheService, SchemaService],
})
export class SchemaModule { }