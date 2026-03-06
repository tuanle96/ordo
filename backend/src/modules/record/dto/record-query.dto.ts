import { Transform } from 'class-transformer';
import { IsArray, IsInt, IsOptional, IsString, Min } from 'class-validator';

export class RecordQueryDto {
    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? JSON.parse(value) : value))
    @IsArray()
    domain?: unknown[];

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

    @IsOptional()
    @Transform(({ value }) => Number(value))
    @IsInt()
    @Min(1)
    limit?: number;

    @IsOptional()
    @Transform(({ value }) => Number(value))
    @IsInt()
    @Min(0)
    offset?: number;

    @IsOptional()
    @IsString()
    order?: string;
}