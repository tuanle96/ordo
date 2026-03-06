import { Transform } from 'class-transformer';
import { IsArray, IsInt, IsOptional, IsString, Min } from 'class-validator';

export class SearchQueryDto {
    @IsOptional()
    @IsString()
    query?: string;

    @IsOptional()
    @Transform(({ value }) => (typeof value === 'string' ? JSON.parse(value) : value))
    @IsArray()
    domain?: unknown[];

    @IsOptional()
    @Transform(({ value }) => Number(value))
    @IsInt()
    @Min(1)
    limit?: number;
}