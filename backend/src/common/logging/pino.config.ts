import type { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import pino from 'pino';
import pinoHttp from 'pino-http';

export function createPinoOptions(nodeEnv: string): pino.LoggerOptions {
    return {
        enabled: nodeEnv !== 'test',
        level: nodeEnv === 'development' ? 'debug' : 'info',
        base: {
            service: 'ordo-backend',
            env: nodeEnv,
        },
        timestamp: pino.stdTimeFunctions.isoTime,
        redact: {
            paths: [
                'authorization',
                'cookie',
                'cookieHeader',
                'headers.authorization',
                'headers.cookie',
                'req.headers.authorization',
                'req.headers.cookie',
                'req.headers.set-cookie',
                'req.body.password',
                'req.body.refreshToken',
                'password',
                'refreshToken',
                'res.headers.set-cookie',
            ],
            censor: '[Redacted]',
        },
        formatters: {
            level: (level) => ({ level }),
        },
    };
}

export function createHttpLogger(configService: ConfigService) {
    const nodeEnv = configService.get<string>('NODE_ENV', 'development');

    return pinoHttp({
        logger: pino(createPinoOptions(nodeEnv)),
        autoLogging: nodeEnv !== 'test',
        genReqId: (req, res) => {
            const headerRequestId = req.headers['x-request-id'];
            const requestId =
                typeof headerRequestId === 'string'
                    ? headerRequestId
                    : Array.isArray(headerRequestId)
                        ? headerRequestId[0]
                        : randomUUID();

            res.setHeader('x-request-id', requestId);

            return requestId;
        },
        customLogLevel: (_req, res, error) => {
            if (error || res.statusCode >= 500) {
                return 'error';
            }

            if (res.statusCode >= 400) {
                return 'warn';
            }

            return 'info';
        },
        customSuccessMessage: (_req, res) => (res.statusCode >= 400 ? 'request completed with warning' : 'request completed'),
        customErrorMessage: () => 'request failed',
        serializers: {
            req: (req) => ({
                requestId: req.id,
                method: req.method,
                path: req.url,
            }),
            res: (res) => ({
                statusCode: res.statusCode,
            }),
        },
    });
}