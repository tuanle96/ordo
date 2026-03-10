import { Controller, Get, UseGuards } from '@nestjs/common';

import type { TokenPayload } from '../../shared';

import type { InstalledModulesResponse } from './module.types';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/auth.guard';
import { ModuleService } from './module.service';

@UseGuards(JwtAuthGuard)
@Controller('modules')
export class ModuleController {
    constructor(private readonly moduleService: ModuleService) { }

    @Get('installed')
    getInstalledModules(
        @CurrentUser() currentUser: TokenPayload,
    ): Promise<InstalledModulesResponse> {
        return this.moduleService.getInstalledModules(currentUser);
    }
}
