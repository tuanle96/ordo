import { Controller, Get, Param, ParseIntPipe, Query, UseGuards } from '@nestjs/common';

import type { RecordData, RecordListResult, TokenPayload } from '@ordo/shared';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/auth.guard';
import { RecordQueryDto } from './dto/record-query.dto';
import { RecordService } from './record.service';

@UseGuards(JwtAuthGuard)
@Controller('records')
export class RecordController {
    constructor(private readonly recordService: RecordService) { }

    @Get(':model')
    listRecords(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Query() query: RecordQueryDto,
    ): Promise<RecordListResult> {
        return this.recordService.listRecords(currentUser, model, query);
    }

    @Get(':model/:id')
    getRecord(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Param('id', ParseIntPipe) id: number,
        @Query() query: RecordQueryDto,
    ): Promise<RecordData> {
        return this.recordService.getRecord(currentUser, model, id, query);
    }
}