import { Module } from '@nestjs/common';

import { OdooModule } from '../../odoo/odoo.module';
import { SchemaController } from './schema.controller';
import { SchemaService } from './schema.service';

@Module({
    imports: [OdooModule],
    controllers: [SchemaController],
    providers: [SchemaService],
})
export class SchemaModule { }