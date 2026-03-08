import { Injectable, NotFoundException } from '@nestjs/common';

import type {
    ChatterMessage,
    ChatterThreadResult,
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

    async createRecord(
        session: OdooSessionContext,
        model: string,
        values: RecordData,
    ): Promise<number> {
        return this.odooRpcService.callKwWithSession<number>({
            session,
            model,
            method: 'create',
            args: [values],
        });
    }

    async updateRecord(
        session: OdooSessionContext,
        model: string,
        id: number,
        values: RecordData,
    ): Promise<boolean> {
        return this.odooRpcService.callKwWithSession<boolean>({
            session,
            model,
            method: 'write',
            args: [[id], values],
        });
    }

    async deleteRecord(
        session: OdooSessionContext,
        model: string,
        id: number,
    ): Promise<boolean> {
        return this.odooRpcService.callKwWithSession<boolean>({
            session,
            model,
            method: 'unlink',
            args: [[id]],
        });
    }

    async runRecordAction(
        session: OdooSessionContext,
        model: string,
        id: number,
        actionName: string,
    ): Promise<unknown> {
        return this.odooRpcService.callKwWithSession<unknown>({
            session,
            model,
            method: actionName,
            args: [[id]],
        });
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

    async listChatter(
        session: OdooSessionContext,
        model: string,
        id: number,
        limit = 20,
        before?: number,
    ): Promise<ChatterThreadResult> {
        const domain: unknown[] = [
            ['res_id', '=', id],
            ['model', '=', model],
            ['message_type', '!=', 'user_notification'],
        ];

        if (before) {
            domain.push(['id', '<', before]);
        }

        const ids = await this.odooRpcService.callKwWithSession<number[]>({
            session,
            model: 'mail.message',
            method: 'search',
            args: [domain],
            kwargs: {
                limit: limit + 1,
                order: 'id desc',
            },
        });

        const hasMore = ids.length > limit;
        const pageIds = ids.slice(0, limit);
        const messages = pageIds.length === 0
            ? []
            : await this.odooRpcService.callKwWithSession<OdooFormattedMessage[]>({
                session,
                model: 'mail.message',
                method: 'message_format',
                args: [pageIds],
            });

        return {
            messages: messages.map((message) => this.mapChatterMessage(message)),
            limit,
            hasMore,
            nextBefore: hasMore ? pageIds.at(-1) : undefined,
        };
    }

    async postChatterNote(
        session: OdooSessionContext,
        model: string,
        id: number,
        body: string,
    ): Promise<ChatterMessage> {
        const messageId = await this.odooRpcService.callKwWithSession<number>({
            session,
            model,
            method: 'message_post',
            args: [[id]],
            kwargs: {
                body,
                message_type: 'comment',
                subtype_xmlid: 'mail.mt_note',
            },
        });
        const [message] = await this.odooRpcService.callKwWithSession<OdooFormattedMessage[]>({
            session,
            model: 'mail.message',
            method: 'message_format',
            args: [[messageId]],
        });

        return this.mapChatterMessage(message);
    }

    private mapChatterMessage(message: OdooFormattedMessage): ChatterMessage {
        return {
            id: message.id,
            body: message.body ?? '',
            plainBody: this.toPlainText(message.body ?? ''),
            date: message.date,
            messageType: message.message_type,
            isNote: message.is_note,
            isDiscussion: message.is_discussion,
            author: message.author
                ? {
                    id: message.author.id,
                    name: message.author.name,
                    type: message.author.type === 'guest' ? 'guest' : 'partner',
                }
                : undefined,
        };
    }

    private toPlainText(value: string): string {
        return value
            .replace(/<br\s*\/?>/gi, '\n')
            .replace(/<\/p>/gi, '\n')
            .replace(/<\/div>/gi, '\n')
            .replace(/<[^>]+>/g, ' ')
            .replace(/&nbsp;/gi, ' ')
            .replace(/&amp;/gi, '&')
            .replace(/&lt;/gi, '<')
            .replace(/&gt;/gi, '>')
            .replace(/&#39;/gi, "'")
            .replace(/&quot;/gi, '"')
            .replace(/[ \t]+\n/g, '\n')
            .replace(/\n{3,}/g, '\n\n')
            .replace(/[ \t]{2,}/g, ' ')
            .trim();
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

interface OdooFormattedMessage {
    id: number;
    body?: string;
    date: string;
    message_type: string;
    is_note: boolean;
    is_discussion: boolean;
    author?: {
        id: number;
        name: string;
        type: string;
    } | false;
}