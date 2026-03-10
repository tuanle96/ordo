import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';

import type {
    AuthenticatedPrincipal,
    LogoutResponse,
    TokenPayload,
    TokenResponse,
} from '@app/shared';

import { CurrentUser } from '@app/common/decorators/current-user.decorator';
import { JwtAuthGuard } from '@app/modules/auth/auth.guard';
import { AuthService } from '@app/modules/auth/auth.service';
import { LoginDto } from '@app/modules/auth/dto/login.dto';
import { RefreshTokenDto } from '@app/modules/auth/dto/refresh-token.dto';

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
    @Post('logout')
    logout(@CurrentUser() currentUser: TokenPayload): Promise<LogoutResponse> {
        return this.authService.logout(currentUser);
    }

    @UseGuards(JwtAuthGuard)
    @Get('me')
    getMe(@CurrentUser() currentUser: TokenPayload): AuthenticatedPrincipal {
        return this.authService.getAuthenticatedPrincipal(currentUser);
    }
}