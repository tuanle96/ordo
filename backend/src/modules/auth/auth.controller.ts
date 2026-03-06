import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';

import type { AuthenticatedPrincipal, TokenPayload, TokenResponse } from '@ordo/shared';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { JwtAuthGuard } from './auth.guard';

@Controller('auth')
export class AuthController {
    constructor(private readonly authService: AuthService) { }

    @Post('login')
    login(@Body() loginDto: LoginDto): Promise<TokenResponse> {
        return this.authService.login(loginDto);
    }

    @UseGuards(JwtAuthGuard)
    @Get('me')
    getMe(@CurrentUser() currentUser: TokenPayload): AuthenticatedPrincipal {
        return this.authService.getAuthenticatedPrincipal(currentUser);
    }
}