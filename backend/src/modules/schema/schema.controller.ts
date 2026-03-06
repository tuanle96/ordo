import { Controller, Get, Param, UseGuards } from '@nestjs/common';

import type { MobileFormSchema, TokenPayload } from '@ordo/shared';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/auth.guard';
import { SchemaService } from './schema.service';

@UseGuards(JwtAuthGuard)
@Controller('schema')
export class SchemaController {
    constructor(private readonly schemaService: SchemaService) { }

    @Get(':model')
    getFormSchema(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
    ): Promise<MobileFormSchema> {
        return this.schemaService.getFormSchema(currentUser, model);
    }
}