import { Transform } from 'class-transformer';
import { IsOptional, IsString, MaxLength } from 'class-validator';

export class CompleteChatterActivityDto {
    @IsOptional()
    @Transform(({ value }) => {
        if (typeof value !== 'string') {
            return undefined;
        }

        const trimmed = value.trim();
        return trimmed.length > 0 ? trimmed : undefined;
    })
    @IsString()
    @MaxLength(4000)
    feedback?: string;
}
