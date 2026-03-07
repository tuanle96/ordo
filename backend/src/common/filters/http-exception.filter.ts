import {
    ArgumentsHost,
    Catch,
    ExceptionFilter,
    HttpException,
    HttpStatus,
    Logger,
} from '@nestjs/common';
import type { Response } from 'express';

import { ApiResponseDto } from '../dto/api-response.dto';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
    private readonly logger = new Logger(HttpExceptionFilter.name);

    catch(exception: unknown, host: ArgumentsHost): void {
        const context = host.switchToHttp();
        const response = context.getResponse<Response>();

        if (exception instanceof HttpException) {
            const status = exception.getStatus();
            const exceptionResponse = exception.getResponse();
            const isObjectResponse =
                typeof exceptionResponse === 'object' && exceptionResponse !== null;
            const message =
                typeof exceptionResponse === 'string'
                    ? exceptionResponse
                    : isObjectResponse && 'message' in exceptionResponse
                        ? String(exceptionResponse.message)
                        : exception.message;

            this.logger.warn({
                event: 'http_exception',
                status,
                message,
            });

            response.status(status).json(
                new ApiResponseDto(false, null, [{ code: String(status), message }], {
                    timestamp: new Date().toISOString(),
                }),
            );
            return;
        }

        this.logger.error({
            event: 'unhandled_exception',
            message: exception instanceof Error ? exception.message : 'Unknown exception',
            trace: exception instanceof Error ? exception.stack : undefined,
        });

        response.status(HttpStatus.INTERNAL_SERVER_ERROR).json(
            new ApiResponseDto(
                false,
                null,
                [{ code: '500', message: 'Internal server error' }],
                { timestamp: new Date().toISOString() },
            ),
        );
    }
}