import { Injectable } from '@nestjs/common';

import { OdooV18Adapter } from './odoo-v18.adapter';

@Injectable()
export class OdooV19Adapter extends OdooV18Adapter {
    override readonly version: string = '19';
}