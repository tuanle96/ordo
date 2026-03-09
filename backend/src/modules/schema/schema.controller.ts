import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';

import type { MobileFormSchema, MobileListSchema, TokenPayload } from '@ordo/shared';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/auth.guard';
import { SchemaService } from './schema.service';

@UseGuards(JwtAuthGuard)
@Controller('schema')
export class SchemaController {
    constructor(private readonly schemaService: SchemaService) { }

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