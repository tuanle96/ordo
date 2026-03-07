import { Transform } from 'class-transformer';
import { IsArray, IsOptional } from 'class-validator';

import type { RecordActionRequest } from '@ordo/shared';

export class RecordActionDto implements RecordActionRequest {
    @IsOptional()
    @Transform(({ value }) => {
        if (Array.isArray(value)) {
            return value;
        }

        if (typeof value === 'string') {
            return value.split(',').map((field) => field.trim()).filter(Boolean);
        }

        return undefined;
    })
    @IsArray()
    fields?: string[];
}