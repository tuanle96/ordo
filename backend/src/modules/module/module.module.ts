import { Module } from '@nestjs/common';

import { OdooModule } from '@app/odoo/odoo.module';
import { ModuleController } from '@app/modules/module/module.controller';
import { ModuleService } from '@app/modules/module/module.service';

@Module({
    imports: [OdooModule],
    controllers: [ModuleController],
    providers: [ModuleService],
})
export class ModuleModule { }
