import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';

import type { AuthenticatedPrincipal, TokenPayload, TokenResponse } from '@ordo/shared';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { JwtAuthGuard } from './auth.guard';

@Controller('auth')
export class AuthController {
    constructor(private readonly authService: AuthService) { }

    @UseGuards(ThrottlerGuard)
    @Throttle({
        default: {
            limit: () => Number(process.env.AUTH_LOGIN_RATE_LIMIT ?? 5),
            ttl: () => Number(process.env.AUTH_LOGIN_RATE_TTL_SECONDS ?? 60) * 1000,
        },
    })
    @Post('login')
    login(@Body() loginDto: LoginDto): Promise<TokenResponse> {
        return this.authService.login(loginDto);
    }

    @UseGuards(ThrottlerGuard)
    @Throttle({
        default: {
            limit: () => Number(process.env.AUTH_REFRESH_RATE_LIMIT ?? 20),
            ttl: () => Number(process.env.AUTH_REFRESH_RATE_TTL_SECONDS ?? 60) * 1000,
        },
    })
    @Post('refresh')
    refresh(@Body() refreshTokenDto: RefreshTokenDto): Promise<TokenResponse> {
        return this.authService.refresh(refreshTokenDto);
    }

    @UseGuards(JwtAuthGuard)
    @Get('me')
    getMe(@CurrentUser() currentUser: TokenPayload): AuthenticatedPrincipal {
        return this.authService.getAuthenticatedPrincipal(currentUser);
    }
}