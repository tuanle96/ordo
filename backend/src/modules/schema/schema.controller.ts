import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';

import type { MobileFormSchema, MobileKanbanSchema, MobileListSchema, TokenPayload } from '@app/shared';

import { CurrentUser } from '@app/common/decorators/current-user.decorator';
import { JwtAuthGuard } from '@app/modules/auth/auth.guard';
import { SchemaService } from '@app/modules/schema/schema.service';

@UseGuards(JwtAuthGuard)
@Controller('schema')
export class SchemaController {
    constructor(private readonly schemaService: SchemaService) { }

    @Get(':model/kanban')
    getKanbanSchema(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Query('fresh') fresh?: string,
    ): Promise<MobileKanbanSchema | null> {
        return this.schemaService.getKanbanSchema(currentUser, model, fresh === 'true');
    }

    @Get(':model/list')
    getListSchema(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Query('fresh') fresh?: string,
    ): Promise<MobileListSchema> {
        return this.schemaService.getListSchema(currentUser, model, fresh === 'true');
    }

    @Get(':model')
    getFormSchema(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Query('fresh') fresh?: string,
    ): Promise<MobileFormSchema> {
        return this.schemaService.getFormSchema(currentUser, model, fresh === 'true');
    }
}