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

    @IsOptional()
    @IsString()
    @MinLength(1)
    REDIS_URL?: string = 'redis://127.0.0.1:6379';

    @IsOptional()
    @IsString()
    @MinLength(1)
    REDIS_KEY_PREFIX?: string = 'ordo';

    @IsOptional()
    @IsNumber()
    @Min(1000)
    REDIS_CONNECT_TIMEOUT_MS?: number = 5000;

    @IsOptional()
    @IsString()
    CORS_ALLOWED_ORIGINS?: string;

    @IsOptional()
    @IsNumber()
    @Min(1)
    AUTH_LOGIN_RATE_LIMIT?: number = 5;

    @IsOptional()
    @IsNumber()
    @Min(1)
    AUTH_LOGIN_RATE_TTL_SECONDS?: number = 60;

    @IsOptional()
    @IsNumber()
    @Min(1)
    AUTH_REFRESH_RATE_LIMIT?: number = 20;

    @IsOptional()
    @IsNumber()
    @Min(1)
    AUTH_REFRESH_RATE_TTL_SECONDS?: number = 60;

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