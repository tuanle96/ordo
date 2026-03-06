import { Injectable } from '@nestjs/common';

import type { OdooAdapter } from './odoo-adapter.interface';
import { OdooV17Adapter } from './odoo-v17.adapter';
import { OdooV18Adapter } from './odoo-v18.adapter';
import { OdooV19Adapter } from './odoo-v19.adapter';

@Injectable()
export class AdapterFactoryService {
    constructor(
        private readonly v17Adapter: OdooV17Adapter,
        private readonly v18Adapter: OdooV18Adapter,
        private readonly v19Adapter: OdooV19Adapter,
    ) { }

    getAdapter(version: string): OdooAdapter {
        switch (version) {
            case '17':
                return this.v17Adapter;
            case '18':
                return this.v18Adapter;
            case '19':
                return this.v19Adapter;
            default:
                throw new Error(`Unsupported Odoo version: ${version}`);
        }
    }
}