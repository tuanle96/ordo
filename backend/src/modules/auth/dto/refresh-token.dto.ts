import { IsJWT, IsString } from 'class-validator';

import type { RefreshTokenRequest } from '../../../shared';

export class RefreshTokenDto implements RefreshTokenRequest {
    @IsString()
    @IsJWT()
    refreshToken!: string;
}