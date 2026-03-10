import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';

import { OdooModule } from '@app/odoo/odoo.module';
import { AuthController } from '@app/modules/auth/auth.controller';
import { JwtAuthGuard } from '@app/modules/auth/auth.guard';
import { AuthService } from '@app/modules/auth/auth.service';
import { JwtStrategy } from '@app/modules/auth/jwt.strategy';

@Module({
    imports: [
        PassportModule.register({ defaultStrategy: 'jwt' }),
        JwtModule.register({}),
        OdooModule,
    ],
    controllers: [AuthController],
    providers: [AuthService, JwtStrategy, JwtAuthGuard],
    exports: [AuthService],
})
export class AuthModule { }