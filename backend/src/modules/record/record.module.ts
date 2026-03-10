import { Module } from '@nestjs/common';

import { OdooModule } from '@app/odoo/odoo.module';
import { RecordController } from '@app/modules/record/record.controller';
import { RecordService } from '@app/modules/record/record.service';
import { SearchController } from '@app/modules/record/search.controller';

@Module({
    imports: [OdooModule],
    controllers: [RecordController, SearchController],
    providers: [RecordService],
})
export class RecordModule { }