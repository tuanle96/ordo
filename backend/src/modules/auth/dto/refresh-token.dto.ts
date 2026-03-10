import { IsJWT, IsString } from 'class-validator';

import type { RefreshTokenRequest } from '@app/shared';

export class RefreshTokenDto implements RefreshTokenRequest {
    @IsString()
    @IsJWT()
    refreshToken!: string;
}