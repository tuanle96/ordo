import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { configureHttpApp } from '@app/app.factory';
import { AppModule } from '@app/app.module';

interface ProviderOverride {
    token: Parameters<ReturnType<typeof Test.createTestingModule>['overrideProvider']>[0];
    useValue: unknown;
}

export async function createTestApp(
    providerOverrides: ProviderOverride[] = [],
): Promise<INestApplication> {
    const moduleBuilder = Test.createTestingModule({
        imports: [AppModule],
    });

    providerOverrides.forEach(({ token, useValue }) => {
        moduleBuilder.overrideProvider(token).useValue(useValue);
    });

    const moduleRef = await moduleBuilder.compile();
    const app = moduleRef.createNestApplication();
    configureHttpApp(app);
    await app.init();

    return app;
}