import { Module } from '@nestjs/common';

import { OdooModule } from '../../odoo/odoo.module';
import { RecordController } from './record.controller';
import { RecordService } from './record.service';
import { SearchController } from './search.controller';

@Module({
    imports: [OdooModule],
    controllers: [RecordController, SearchController],
    providers: [RecordService],
})
export class RecordModule { }