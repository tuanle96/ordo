import { Injectable, LoggerService } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import pino, { type Logger } from 'pino';

import { createPinoOptions } from '@app/common/logging/pino.config';

@Injectable()
export class PinoLoggerService implements LoggerService {
    private readonly logger: Logger;

    constructor(configService: ConfigService) {
        this.logger = pino(createPinoOptions(configService.get<string>('NODE_ENV', 'development')));
    }

    log(message: unknown, context?: string): void {
        this.logger.info(this.normalizePayload(message, context));
    }

    error(message: unknown, trace?: string, context?: string): void {
        this.logger.error(this.normalizePayload(message, context, trace));
    }

    warn(message: unknown, context?: string): void {
        this.logger.warn(this.normalizePayload(message, context));
    }

    debug(message: unknown, context?: string): void {
        this.logger.debug(this.normalizePayload(message, context));
    }

    verbose(message: unknown, context?: string): void {
        this.logger.trace(this.normalizePayload(message, context));
    }

    private normalizePayload(message: unknown, context?: string, trace?: string) {
        if (message instanceof Error) {
            return {
                context,
                message: message.message,
                trace: message.stack ?? trace,
            };
        }

        if (typeof message === 'object' && message !== null) {
            return {
                context,
                trace,
                ...message,
            };
        }

        return {
            context,
            trace,
            message: String(message),
        };
    }
}