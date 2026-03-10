import { Transform } from 'class-transformer';
import { IsArray, IsInt, IsObject, IsOptional, IsString } from 'class-validator';

import type { OnchangeRequest, RecordData } from '@app/shared';

export class RecordOnchangeDto implements OnchangeRequest {
    @IsObject()
    values!: RecordData;

    @IsString()
    triggerField!: string;

    @IsOptional()
    @IsInt()
    recordId?: number;

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