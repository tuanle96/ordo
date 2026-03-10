import { Controller, Get, UseGuards } from '@nestjs/common';

import type { TokenPayload } from '@app/shared';

import { CurrentUser } from '@app/common/decorators/current-user.decorator';
import { JwtAuthGuard } from '@app/modules/auth/auth.guard';
import type { InstalledModulesResponse } from '@app/modules/module/module.types';
import { ModuleService } from '@app/modules/module/module.service';

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
