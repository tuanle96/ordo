import {
    Body,
    Controller,
    Delete,
    Get,
    Param,
    ParseIntPipe,
    Patch,
    Post,
    Query,
    UseGuards,
} from '@nestjs/common';

import type {
    ChatterDetailsResult,
    ChatterMessage,
    ChatterThreadResult,
    DeleteRecordResult,
    OnchangeResult,
    RecordActionResult,
    RecordData,
    RecordListResult,
    RecordMutationResult,
    TokenPayload,
} from '@ordo/shared';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/auth.guard';
import { ChatterQueryDto } from './dto/chatter-query.dto';
import { CompleteChatterActivityDto } from './dto/complete-chatter-activity.dto';
import { PostChatterNoteDto } from './dto/post-chatter-note.dto';
import { RecordActionDto } from './dto/record-action.dto';
import { RecordOnchangeDto } from './dto/record-onchange.dto';
import { RecordMutationDto } from './dto/record-mutation.dto';
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

    @Get(':model/:id/chatter')
    listChatter(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Param('id', ParseIntPipe) id: number,
        @Query() query: ChatterQueryDto,
    ): Promise<ChatterThreadResult> {
        return this.recordService.listChatter(currentUser, model, id, query);
    }

    @Get(':model/:id/chatter/details')
    getChatterDetails(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Param('id', ParseIntPipe) id: number,
    ): Promise<ChatterDetailsResult> {
        return this.recordService.getChatterDetails(currentUser, model, id);
    }

    @Post(':model/:id/chatter/note')
    postChatterNote(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Param('id', ParseIntPipe) id: number,
        @Body() body: PostChatterNoteDto,
    ): Promise<ChatterMessage> {
        return this.recordService.postChatterNote(currentUser, model, id, body);
    }

    @Post(':model/:id/chatter/follow')
    followRecord(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Param('id', ParseIntPipe) id: number,
    ): Promise<ChatterDetailsResult> {
        return this.recordService.followRecord(currentUser, model, id);
    }

    @Delete(':model/:id/chatter/follow')
    unfollowRecord(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Param('id', ParseIntPipe) id: number,
    ): Promise<ChatterDetailsResult> {
        return this.recordService.unfollowRecord(currentUser, model, id);
    }

    @Post(':model/:id/chatter/activities/:activityId/done')
    completeChatterActivity(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Param('id', ParseIntPipe) id: number,
        @Param('activityId', ParseIntPipe) activityId: number,
        @Body() body: CompleteChatterActivityDto = new CompleteChatterActivityDto(),
    ): Promise<ChatterDetailsResult> {
        return this.recordService.completeChatterActivity(currentUser, model, id, activityId, body);
    }

    @Post(':model')
    createRecord(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Body() body: RecordMutationDto,
    ): Promise<RecordMutationResult> {
        return this.recordService.createRecord(currentUser, model, body);
    }

    @Post(':model/onchange')
    runOnchange(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Body() body: RecordOnchangeDto,
    ): Promise<OnchangeResult> {
        return this.recordService.runOnchange(currentUser, model, body);
    }

    @Patch(':model/:id')
    updateRecord(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Param('id', ParseIntPipe) id: number,
        @Body() body: RecordMutationDto,
    ): Promise<RecordMutationResult> {
        return this.recordService.updateRecord(currentUser, model, id, body);
    }

    @Delete(':model/:id')
    deleteRecord(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Param('id', ParseIntPipe) id: number,
    ): Promise<DeleteRecordResult> {
        return this.recordService.deleteRecord(currentUser, model, id);
    }

    @Post(':model/:id/actions/:actionName')
    runRecordAction(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Param('id', ParseIntPipe) id: number,
        @Param('actionName') actionName: string,
        @Body() body: RecordActionDto = new RecordActionDto(),
    ): Promise<RecordActionResult> {
        return this.recordService.runRecordAction(currentUser, model, id, actionName, body);
    }
}