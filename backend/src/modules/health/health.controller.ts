import { Controller, Get } from '@nestjs/common';

import { HealthService } from '@app/modules/health/health.service';

@Controller('health')
export class HealthController {
    constructor(private readonly healthService: HealthService) { }

    @Get()
    getHealth() {
        return this.healthService.getStatus();
    }
}