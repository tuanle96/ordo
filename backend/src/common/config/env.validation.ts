import {
    IsNumber,
    IsOptional,
    IsString,
    Matches,
    Min,
    MinLength,
} from 'class-validator';

export class EnvironmentVariables {
    // Handoff 2 will extend this with auth, Redis, and Odoo-specific runtime settings.
    @IsOptional()
    @IsNumber()
    @Min(1)
    PORT?: number = 3000;

    @IsOptional()
    @IsString()
    NODE_ENV?: string = 'development';

    @IsOptional()
    @IsString()
    @Matches(/^api\/v\d+\/[a-z0-9/-]+$/i)
    API_PREFIX?: string = 'api/v1/mobile';

    @IsOptional()
    @IsNumber()
    @Min(1000)
    ODOO_REQUEST_TIMEOUT_MS?: number = 15000;

    @IsString()
    @MinLength(12)
    JWT_ACCESS_SECRET!: string;

    @IsString()
    @MinLength(12)
    JWT_REFRESH_SECRET!: string;

    @IsOptional()
    @IsNumber()
    @Min(60)
    JWT_ACCESS_EXPIRES_IN_SECONDS?: number = 900;

    @IsOptional()
    @IsNumber()
    @Min(300)
    JWT_REFRESH_EXPIRES_IN_SECONDS?: number = 604800;

    @IsOptional()
    @IsNumber()
    @Min(60)
    ODOO_SESSION_TTL_SECONDS?: number = 1800;
}