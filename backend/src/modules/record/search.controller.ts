import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';

import type { NameSearchResult, TokenPayload } from '@app/shared';

import { CurrentUser } from '@app/common/decorators/current-user.decorator';
import { JwtAuthGuard } from '@app/modules/auth/auth.guard';
import { SearchQueryDto } from '@app/modules/record/dto/search-query.dto';
import { RecordService } from '@app/modules/record/record.service';

@UseGuards(JwtAuthGuard)
@Controller('search')
export class SearchController {
    constructor(private readonly recordService: RecordService) { }

    @Get(':model')
    search(
        @CurrentUser() currentUser: TokenPayload,
        @Param('model') model: string,
        @Query() query: SearchQueryDto,
    ): Promise<NameSearchResult[]> {
        return this.recordService.search(currentUser, model, query);
    }
}