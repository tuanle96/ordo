import { Injectable } from '@nestjs/common';

@Injectable()
export class HealthService {
    getStatus() {
        return {
            service: 'ordo-backend',
            status: 'ok',
            timestamp: new Date().toISOString(),
        };
    }
}