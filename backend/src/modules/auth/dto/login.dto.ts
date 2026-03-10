import { IsNotEmpty, IsString, IsUrl } from 'class-validator';

import type { LoginRequest } from '../../../shared';

export class LoginDto implements LoginRequest {
    @IsUrl({ require_tld: false }, { message: 'odooUrl must be a valid URL' })
    odooUrl!: string;

    @IsString()
    @IsNotEmpty()
    db!: string;

    @IsString()
    @IsNotEmpty()
    login!: string;

    @IsString()
    @IsNotEmpty()
    password!: string;
}