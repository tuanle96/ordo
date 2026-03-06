import {
    CallHandler,
    ExecutionContext,
    Injectable,
    NestInterceptor,
} from '@nestjs/common';
import { map, Observable } from 'rxjs';

import { ApiResponseDto } from '../dto/api-response.dto';

@Injectable()
export class TransformInterceptor<T>
    implements NestInterceptor<T, ApiResponseDto<T>> {
    intercept(
        _context: ExecutionContext,
        next: CallHandler<T>,
    ): Observable<ApiResponseDto<T>> {
        return next.handle().pipe(
            map(
                (data) =>
                    new ApiResponseDto(true, data, [], {
                        timestamp: new Date().toISOString(),
                    }),
            ),
        );
    }
}