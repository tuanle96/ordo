import { createParamDecorator, ExecutionContext } from '@nestjs/common';

import type { TokenPayload } from '../../shared';

export const CurrentUser = createParamDecorator(
    (_data: unknown, context: ExecutionContext): TokenPayload => {
        const request = context.switchToHttp().getRequest<{ user: TokenPayload }>();
        return request.user;
    },
);