import { Injectable } from '@nestjs/common';

import { OdooV17Adapter } from './odoo-v17.adapter';

@Injectable()
export class OdooV18Adapter extends OdooV17Adapter {
    override readonly version: string = '18';
}