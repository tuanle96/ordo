import { Transform } from 'class-transformer';
import { IsArray, IsObject, IsOptional } from 'class-validator';

import type { RecordData, RecordMutationRequest } from '@app/shared';

export class RecordMutationDto implements RecordMutationRequest {
    @IsObject()
    values!: RecordData;

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