import { Module } from '@nestjs/common';

import { OdooModule } from '../../odoo/odoo.module';
import { ModuleController } from './module.controller';
import { ModuleService } from './module.service';

@Module({
    imports: [OdooModule],
    controllers: [ModuleController],
    providers: [ModuleService],
})
export class ModuleModule { }
