import { Injectable, NotFoundException } from '@nestjs/common';

import type {
    MobileFormSchema,
    NameSearchResult,
    RecordData,
    RecordListQuery,
    RecordListResult,
} from '@ordo/shared';

import { OdooAdapter } from './odoo-adapter.interface';
import { OdooRpcService } from '../rpc/odoo-rpc.service';
import { MobileSchemaBuilderService } from '../schema/mobile-schema-builder.service';
import type { OdooSessionContext } from '../session/odoo-session.types';

@Injectable()
export class OdooV17Adapter implements OdooAdapter {
    readonly version: string = '17';

    constructor(
        private readonly odooRpcService: OdooRpcService,
        private readonly schemaBuilder: MobileSchemaBuilderService,
    ) { }

    async getFormSchema(session: OdooSessionContext, model: string): Promise<MobileFormSchema> {
        const fieldsMeta = await this.odooRpcService.callKwWithSession<Record<string, OdooFieldMeta>>({
            session,
            model,
            method: 'fields_get',
            kwargs: {
                attributes: ['string', 'type', 'readonly', 'required', 'relation', 'selection', 'domain', 'digits', 'currency_field'],
            },
        });
        const view = await this.odooRpcService.callKwWithSession<{ arch: string }>({
            session,
            model,
            method: 'get_view',
            kwargs: {
                view_type: 'form',
            },
        });

        return this.schemaBuilder.build(model, view.arch, fieldsMeta);
    }

    async getRecord(
        session: OdooSessionContext,
        model: string,
        id: number,
        fields?: string[],
    ): Promise<RecordData> {
        const result = await this.odooRpcService.callKwWithSession<RecordData[]>({
            session,
            model,
            method: 'read',
            args: [[id]],
            kwargs: fields && fields.length > 0 ? { fields } : {},
        });

        const [record] = result;
        if (!record) {
            throw new NotFoundException(`Record ${model}:${id} was not found`);
        }

        return record;
    }

    async searchRecords(
        session: OdooSessionContext,
        model: string,
        query: RecordListQuery,
    ): Promise<RecordListResult> {
        const items = await this.odooRpcService.callKwWithSession<RecordData[]>({
            session,
            model,
            method: 'search_read',
            kwargs: {
                domain: query.domain ?? [],
                fields: query.fields,
                limit: query.limit ?? 40,
                offset: query.offset ?? 0,
                order: query.order,
            },
        });

        return {
            items,
            limit: query.limit ?? 40,
            offset: query.offset ?? 0,
        };
    }

    async nameSearch(
        session: OdooSessionContext,
        model: string,
        query: string,
        domain: unknown[] = [],
        limit = 20,
    ): Promise<NameSearchResult[]> {
        const result = await this.odooRpcService.callKwWithSession<Array<[number, string]>>({
            session,
            model,
            method: 'name_search',
            args: [query, domain, 'ilike', limit],
        });

        return result.map(([id, name]) => ({ id, name }));
    }
}

interface OdooFieldMeta {
    string?: string;
    type: MobileFormSchema['sections'][number]['fields'][number]['type'];
    readonly?: boolean;
    required?: boolean;
    relation?: string;
    selection?: [string, string][];
    domain?: string;
    digits?: [number, number];
    currency_field?: string;
}