import { Transform } from 'class-transformer';
import { IsInt, IsOptional, IsString, Matches, MaxLength, Min } from 'class-validator';

const trimOptionalString = ({ value }: { value: unknown }): string | undefined => {
    if (typeof value !== 'string') {
        return undefined;
    }

    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
};

export class ScheduleChatterActivityDto {
    @Transform(({ value }) => Number(value))
    @IsInt()
    @Min(1)
    activityTypeId!: number;

    @IsOptional()
    @Transform(trimOptionalString)
    @IsString()
    @MaxLength(255)
    summary?: string;

    @IsOptional()
    @Transform(trimOptionalString)
    @IsString()
    @MaxLength(4000)
    note?: string;

    @IsOptional()
    @Transform(trimOptionalString)
    @IsString()
    @Matches(/^\d{4}-\d{2}-\d{2}$/)
    dateDeadline?: string;
}