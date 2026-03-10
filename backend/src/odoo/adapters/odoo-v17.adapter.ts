import { BadGatewayException, Injectable, NotFoundException } from '@nestjs/common';

import type {
    ChatterActivity,
    ChatterActivityTypeOption,
    ChatterDetailsResult,
    ChatterFollower,
    ChatterMessage,
    ChatterThreadResult,
    MobileFormSchema,
    MobileListSchema,
    NameSearchResult,
    OnchangeRequest,
    OnchangeResult,
    RecordData,
    RecordListQuery,
    RecordListResult,
} from '@app/shared';

import type { BrowseMenuNode, InstalledModuleInfo } from '@app/modules/module/module.types';

import { OdooAdapter } from '@app/odoo/adapters/odoo-adapter.interface';
import { OdooRpcService } from '@app/odoo/rpc/odoo-rpc.service';
import type { OdooFieldsSpec } from '@app/odoo/rpc/odoo-rpc.types';
import { MobileListSchemaBuilderService } from '@app/odoo/schema/mobile-list-schema-builder.service';
import { MobileSchemaBuilderService } from '@app/odoo/schema/mobile-schema-builder.service';
import type { OdooSessionContext } from '@app/odoo/session/odoo-session.types';

@Injectable()
export class OdooV17Adapter implements OdooAdapter {
    readonly version: string = '17';

    constructor(
        private readonly odooRpcService: OdooRpcService,
        private readonly schemaBuilder: MobileSchemaBuilderService,
        private readonly listSchemaBuilder: MobileListSchemaBuilderService,
    ) { }

    async isModelAvailable(session: OdooSessionContext, model: string): Promise<boolean> {
        try {
            await this.odooRpcService.callKwWithSession<Record<string, OdooFieldMeta>>({
                session,
                model,
                method: 'fields_get',
                kwargs: {
                    attributes: ['string'],
                },
            });

            return true;
        } catch (error) {
            if (error instanceof NotFoundException) {
                return false;
            }

            throw error;
        }
    }

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

    async getListSchema(session: OdooSessionContext, model: string): Promise<MobileListSchema> {
        const fieldsMeta = await this.odooRpcService.callKwWithSession<Record<string, OdooFieldMeta>>({
            session,
            model,
            method: 'fields_get',
            kwargs: {
                attributes: ['string', 'type', 'relation', 'selection'],
            },
        });
        const treeView = await this.odooRpcService.callKwWithSession<{ arch: string }>({
            session,
            model,
            method: 'get_view',
            kwargs: {
                view_type: 'tree',
            },
        });
        const searchView = await this.odooRpcService.callKwWithSession<{ arch: string }>({
            session,
            model,
            method: 'get_view',
            kwargs: {
                view_type: 'search',
            },
        });

        return this.listSchemaBuilder.build(model, treeView.arch, searchView.arch, fieldsMeta);
    }

    async getDefaultValues(
        session: OdooSessionContext,
        model: string,
        fields: string[],
    ): Promise<RecordData> {
        if (fields.length === 0) {
            return {};
        }

        return this.odooRpcService.callKwWithSession<RecordData>({
            session,
            model,
            method: 'default_get',
            args: [fields],
        });
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

    async runOnchange(
        session: OdooSessionContext,
        model: string,
        request: OnchangeRequest,
    ): Promise<OnchangeResult> {
        const fieldsSpec = this.buildOnchangeFieldsSpec(request);
        const result = await this.odooRpcService.runModelOnchangeWithSession(
            session,
            model,
            request.values,
            request.triggerField,
            fieldsSpec,
            request.recordId,
        );

        return {
            values: this.normalizeOnchangeValues(result.value),
            warnings: this.normalizeOnchangeWarnings(result.warning),
            domains: this.normalizeOnchangeDomains(result.domain),
        };
    }

    private buildOnchangeFieldsSpec(request: OnchangeRequest): OdooFieldsSpec {
        const fieldNames = Array.from(new Set([
            ...(request.fields ?? []),
            ...Object.keys(request.values ?? {}),
            request.triggerField,
        ].filter((fieldName): fieldName is string => typeof fieldName === 'string' && fieldName.length > 0)));

        return fieldNames.reduce<OdooFieldsSpec>((spec, fieldName) => {
            spec[fieldName] = {};
            return spec;
        }, {});
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
        const domain = query.domain ?? [];
        const limit = query.limit ?? 40;
        const offset = query.offset ?? 0;

        const [items, total] = await Promise.all([
            this.odooRpcService.callKwWithSession<RecordData[]>({
                session,
                model,
                method: 'search_read',
                kwargs: {
                    domain,
                    fields: query.fields,
                    limit,
                    offset,
                    order: query.order,
                },
            }),
            this.odooRpcService.callKwWithSession<number>({
                session,
                model,
                method: 'search_count',
                args: [domain],
            }),
        ]);

        return {
            items,
            limit,
            offset,
            total,
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

    async getChatterDetails(
        session: OdooSessionContext,
        model: string,
        id: number,
    ): Promise<ChatterDetailsResult> {
        const currentPartnerId = await this.getCurrentPartnerId(session);
        const followerDomain: unknown[] = [
            ['res_id', '=', id],
            ['res_model', '=', model],
        ];
        const activityDomain: unknown[] = [
            ['res_id', '=', id],
            ['res_model', '=', model],
        ];

        const [followersRaw, followersCount, selfFollowerRaw, activitiesRaw, activityTypesRaw] = await Promise.all([
            this.odooRpcService.callKwWithSession<OdooFormattedFollower[]>({
                session,
                model,
                method: 'message_get_followers',
                args: [[id]],
                kwargs: {
                    limit: 100,
                },
            }),
            this.odooRpcService.callKwWithSession<number>({
                session,
                model: 'mail.followers',
                method: 'search_count',
                args: [followerDomain],
            }),
            this.odooRpcService.callKwWithSession<OdooFormattedFollower[]>({
                session,
                model: 'mail.followers',
                method: 'search_read',
                args: [[
                    ...followerDomain,
                    ['partner_id', '=', currentPartnerId],
                ]],
                kwargs: {
                    limit: 1,
                    fields: ['id', 'partner_id', 'name', 'email', 'is_active'],
                },
            }),
            this.odooRpcService.callKwWithSession<OdooFormattedActivity[]>({
                session,
                model: 'mail.activity',
                method: 'search_read',
                args: [activityDomain],
                kwargs: {
                    fields: ['id', 'activity_type_id', 'summary', 'note', 'date_deadline', 'state', 'can_write', 'user_id'],
                    order: 'date_deadline asc, id asc',
                },
            }),
            this.odooRpcService.callKwWithSession<OdooActivityTypeRecord[]>({
                session,
                model: 'mail.activity.type',
                method: 'search_read',
                args: [[
                    ['active', '=', true],
                    '|',
                    ['res_model', '=', false],
                    ['res_model', '=', model],
                ]],
                kwargs: {
                    fields: ['id', 'name', 'summary', 'icon', 'default_note'],
                    order: 'sequence asc, id asc',
                },
            }),
        ]);

        const followers = followersRaw.map((follower) => this.mapChatterFollower(follower, currentPartnerId));
        const selfFollower = followers.find((follower) => follower.isSelf)
            ?? selfFollowerRaw.map((follower) => this.mapChatterFollower(follower, currentPartnerId))[0];

        return {
            followers,
            followersCount,
            selfFollower,
            activities: activitiesRaw.map((activity) => this.mapChatterActivity(activity)),
            availableActivityTypes: activityTypesRaw.map((activityType) => this.mapChatterActivityType(activityType)),
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

    async followRecord(
        session: OdooSessionContext,
        model: string,
        id: number,
    ): Promise<ChatterDetailsResult> {
        const partnerId = await this.getCurrentPartnerId(session);

        await this.odooRpcService.callKwWithSession<boolean>({
            session,
            model,
            method: 'message_subscribe',
            args: [[id], [partnerId]],
        });

        return this.getChatterDetails(session, model, id);
    }

    async unfollowRecord(
        session: OdooSessionContext,
        model: string,
        id: number,
    ): Promise<ChatterDetailsResult> {
        const partnerId = await this.getCurrentPartnerId(session);

        await this.odooRpcService.callKwVoidWithSession({
            session,
            model,
            method: 'message_unsubscribe',
            args: [[id], [partnerId]],
        });

        return this.getChatterDetails(session, model, id);
    }

    async completeChatterActivity(
        session: OdooSessionContext,
        model: string,
        id: number,
        activityId: number,
        feedback?: string,
    ): Promise<ChatterDetailsResult> {
        const matchingActivities = await this.odooRpcService.callKwWithSession<Array<{ id: number }>>({
            session,
            model: 'mail.activity',
            method: 'search_read',
            args: [[
                ['id', '=', activityId],
                ['res_id', '=', id],
                ['res_model', '=', model],
            ]],
            kwargs: {
                limit: 1,
                fields: ['id'],
            },
        });

        if (matchingActivities.length === 0) {
            throw new NotFoundException(`Activity ${activityId} was not found on ${model}:${id}`);
        }

        await this.odooRpcService.callKwWithSession<number | false>({
            session,
            model: 'mail.activity',
            method: 'action_feedback',
            args: feedback ? [[activityId], feedback] : [[activityId]],
        });

        return this.getChatterDetails(session, model, id);
    }

    async scheduleChatterActivity(
        session: OdooSessionContext,
        model: string,
        id: number,
        activityTypeId: number,
        values?: {
            summary?: string;
            note?: string;
            dateDeadline?: string;
        },
    ): Promise<ChatterDetailsResult> {
        const matchingTypes = await this.odooRpcService.callKwWithSession<Array<{ id: number }>>({
            session,
            model: 'mail.activity.type',
            method: 'search_read',
            args: [[
                ['id', '=', activityTypeId],
                ['active', '=', true],
                '|',
                ['res_model', '=', false],
                ['res_model', '=', model],
            ]],
            kwargs: {
                limit: 1,
                fields: ['id'],
            },
        });

        if (matchingTypes.length === 0) {
            throw new NotFoundException(`Activity type ${activityTypeId} is not available for ${model}`);
        }

        const kwargs: Record<string, unknown> = {
            activity_type_id: activityTypeId,
            user_id: session.uid,
            automated: false,
        };

        if (values?.summary) {
            kwargs.summary = values.summary;
        }

        if (values?.note) {
            kwargs.note = values.note;
        }

        if (values?.dateDeadline) {
            kwargs.date_deadline = values.dateDeadline;
        }

        await this.odooRpcService.callKwWithSession<unknown>({
            session,
            model,
            method: 'activity_schedule',
            args: [[id]],
            kwargs,
        });

        return this.getChatterDetails(session, model, id);
    }

    async getInstalledModules(
        session: OdooSessionContext,
    ): Promise<InstalledModuleInfo[]> {
        const records = await this.odooRpcService.callKwWithSession<
            Array<{ name: string; shortdesc: string }>
        >({
            session,
            model: 'ir.module.module',
            method: 'search_read',
            kwargs: {
                domain: [
                    ['state', '=', 'installed'],
                    ['application', '=', true],
                ],
                fields: ['name', 'shortdesc'],
                order: 'shortdesc asc, name asc',
            },
        });

        return records.map((record) => ({
            name: record.name,
            displayName: record.shortdesc,
        }));
    }

    async getBrowseMenuTree(
        session: OdooSessionContext,
    ): Promise<BrowseMenuNode[]> {
        const menuRecords = await this.odooRpcService.callKwWithSession<Array<OdooMenuRecord>>({
            session,
            model: 'ir.ui.menu',
            method: 'search_read',
            kwargs: {
                domain: [['active', '=', true]],
                fields: ['id', 'name', 'parent_id', 'action'],
                order: 'sequence asc, id asc',
            },
        });

        const actionIDs = Array.from(new Set(menuRecords
            .map((menuRecord) => this.parseWindowActionID(menuRecord.action))
            .filter((actionID): actionID is number => actionID !== undefined)));

        if (actionIDs.length === 0) {
            return [];
        }

        const actions = await this.odooRpcService.callKwWithSession<Array<OdooWindowActionRecord>>({
            session,
            model: 'ir.actions.act_window',
            method: 'read',
            args: [actionIDs],
            kwargs: {
                fields: ['id', 'name', 'res_model', 'view_mode', 'target'],
            },
        });

        const actionsByID = new Map(actions.map((action) => [action.id, action]));

        return this.buildBrowseMenuTree(menuRecords, actionsByID);
    }

    private buildBrowseMenuTree(
        menuRecords: OdooMenuRecord[],
        actionsByID: Map<number, OdooWindowActionRecord>,
    ): BrowseMenuNode[] {
        const menuRecordsByID = new Map(menuRecords.map((menuRecord) => [menuRecord.id, menuRecord]));
        const childMenuIDsByParentID = new Map<number | undefined, number[]>();

        for (const menuRecord of menuRecords) {
            const parentID = this.extractParentMenuID(menuRecord.parent_id);
            const existingChildren = childMenuIDsByParentID.get(parentID) ?? [];
            existingChildren.push(menuRecord.id);
            childMenuIDsByParentID.set(parentID, existingChildren);
        }

        const rootMenuIDs = menuRecords
            .filter((menuRecord) => {
                const parentID = this.extractParentMenuID(menuRecord.parent_id);
                return parentID === undefined;
            })
            .map((menuRecord) => menuRecord.id);

        return rootMenuIDs
            .map((menuID) => this.buildBrowseMenuNode(menuID, true, menuRecordsByID, childMenuIDsByParentID, actionsByID))
            .filter((menuNode): menuNode is BrowseMenuNode => menuNode !== undefined);
    }

    private buildBrowseMenuNode(
        menuID: number,
        isRoot: boolean,
        menuRecordsByID: Map<number, OdooMenuRecord>,
        childMenuIDsByParentID: Map<number | undefined, number[]>,
        actionsByID: Map<number, OdooWindowActionRecord>,
    ): BrowseMenuNode | undefined {
        const menuRecord = menuRecordsByID.get(menuID);
        if (!menuRecord) {
            return undefined;
        }

        const children = (childMenuIDsByParentID.get(menuID) ?? [])
            .map((childMenuID) => this.buildBrowseMenuNode(childMenuID, false, menuRecordsByID, childMenuIDsByParentID, actionsByID))
            .filter((menuNode): menuNode is BrowseMenuNode => menuNode !== undefined);

        const model = this.resolveBrowseableModel(menuRecord.action, actionsByID);
        if (!model && children.length === 0) {
            return undefined;
        }

        const resolvedModel = model ?? (isRoot ? this.findFirstBrowseableModel(children) : undefined);

        return {
            id: menuRecord.id,
            name: this.normalizeBrowseTitle(menuRecord.name ?? resolvedModel ?? `Menu ${menuRecord.id}`),
            kind: isRoot ? 'app' : children.length === 0 ? 'leaf' : 'category',
            model: resolvedModel,
            children,
        };
    }

    private findFirstBrowseableModel(children: BrowseMenuNode[]): string | undefined {
        for (const child of children) {
            if (child.model) {
                return child.model;
            }

            const descendantModel = this.findFirstBrowseableModel(child.children);
            if (descendantModel) {
                return descendantModel;
            }
        }

        return undefined;
    }

    private resolveBrowseableModel(
        action: OdooMenuActionReference,
        actionsByID: Map<number, OdooWindowActionRecord>,
    ): string | undefined {
        const actionID = this.parseWindowActionID(action);
        if (!actionID) {
            return undefined;
        }

        const actionRecord = actionsByID.get(actionID);
        if (!actionRecord || !this.isBrowseableWindowAction(actionRecord)) {
            return undefined;
        }

        return actionRecord.res_model.trim();
    }

    private extractParentMenuID(parent: OdooMenuParentReference): number | undefined {
        if (Array.isArray(parent) && typeof parent[0] === 'number') {
            return parent[0];
        }

        return undefined;
    }

    private parseWindowActionID(action: OdooMenuActionReference): number | undefined {
        if (typeof action === 'string') {
            const [referenceModel, referenceID] = action.split(',');
            return referenceModel === 'ir.actions.act_window' && /^\d+$/.test(referenceID ?? '')
                ? Number(referenceID)
                : undefined;
        }

        if (Array.isArray(action) && action.length >= 2) {
            const [referenceModel, referenceID] = action;
            return referenceModel === 'ir.actions.act_window' && typeof referenceID === 'number'
                ? referenceID
                : undefined;
        }

        return undefined;
    }

    private isBrowseableWindowAction(action: OdooWindowActionRecord): action is OdooWindowActionRecord & { res_model: string } {
        if (typeof action.res_model !== 'string' || action.res_model.trim().length === 0) {
            return false;
        }

        if (action.target === 'new') {
            return false;
        }

        if (typeof action.view_mode !== 'string' || action.view_mode.trim().length === 0) {
            return true;
        }

        const supportedViewModes = new Set(['tree', 'list', 'kanban']);
        return action.view_mode
            .split(',')
            .map((viewMode) => viewMode.trim())
            .some((viewMode) => supportedViewModes.has(viewMode));
    }

    private normalizeBrowseTitle(title: string): string {
        const trimmedTitle = title.trim();
        return trimmedTitle.length > 0 ? trimmedTitle : 'Browse Records';
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

    private mapChatterFollower(
        follower: OdooFormattedFollower,
        currentPartnerId: number,
    ): ChatterFollower {
        const partner = this.extractIdName(follower.partner_id);

        return {
            id: follower.id,
            partnerId: partner?.id ?? 0,
            name: follower.name ?? follower.display_name ?? partner?.name ?? 'Unknown follower',
            email: this.normalizeOptionalString(follower.email),
            isActive: follower.is_active ?? true,
            isSelf: partner?.id === currentPartnerId,
        };
    }

    private mapChatterActivity(activity: OdooFormattedActivity): ChatterActivity {
        const activityType = this.extractIdName(activity.activity_type_id);
        const assignedUser = this.extractIdName(activity.user_id);
        const note = typeof activity.note === 'string' ? activity.note : '';

        return {
            id: activity.id,
            typeId: activityType?.id,
            typeName: activityType?.name ?? 'Activity',
            summary: this.normalizeOptionalString(activity.summary),
            note,
            plainNote: this.toPlainText(note),
            dateDeadline: activity.date_deadline,
            state: activity.state ?? 'planned',
            canWrite: activity.can_write ?? false,
            assignedUser,
        };
    }

    private mapChatterActivityType(activityType: OdooActivityTypeRecord): ChatterActivityTypeOption {
        return {
            id: activityType.id,
            name: activityType.name,
            summary: this.normalizeOptionalString(activityType.summary),
            icon: this.normalizeOptionalString(activityType.icon),
            defaultNote: this.normalizeOptionalString(activityType.default_note),
        };
    }

    private async getCurrentPartnerId(session: OdooSessionContext): Promise<number> {
        const [user] = await this.odooRpcService.callKwWithSession<OdooCurrentUserRecord[]>({
            session,
            model: 'res.users',
            method: 'read',
            args: [[session.uid]],
            kwargs: {
                fields: ['partner_id'],
            },
        });
        const partner = this.extractIdName(user?.partner_id);

        if (!partner?.id) {
            throw new BadGatewayException('Unable to resolve the authenticated partner for chatter follower operations.');
        }

        return partner.id;
    }

    private extractIdName(value: OdooRelationValue): { id: number; name: string } | undefined {
        if (Array.isArray(value) && typeof value[0] === 'number') {
            return {
                id: value[0],
                name: typeof value[1] === 'string' ? value[1] : String(value[0]),
            };
        }

        if (typeof value === 'number') {
            return {
                id: value,
                name: String(value),
            };
        }

        return undefined;
    }

    private normalizeOptionalString(value: string | false | null | undefined): string | undefined {
        return typeof value === 'string' && value.trim().length > 0 ? value.trim() : undefined;
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

    private normalizeOnchangeValues(value: unknown): RecordData {
        if (value === undefined || value === null) {
            return {};
        }

        if (!this.isPlainObject(value)) {
            throw new BadGatewayException('Odoo onchange returned an unsupported value payload.');
        }

        return value as RecordData;
    }

    private normalizeOnchangeWarnings(warning: unknown): OnchangeResult['warnings'] {
        if (warning === undefined || warning === null) {
            return undefined;
        }

        if (!this.isPlainObject(warning) || typeof warning.title !== 'string' || typeof warning.message !== 'string') {
            throw new BadGatewayException('Odoo onchange returned an unsupported warning payload.');
        }

        return [{
            title: warning.title,
            message: warning.message,
            type: warning.type === 'warning' || warning.type === 'info' ? warning.type : undefined,
        }];
    }

    private normalizeOnchangeDomains(domain: unknown): OnchangeResult['domains'] {
        if (domain === undefined || domain === null) {
            return undefined;
        }

        if (!this.isPlainObject(domain)) {
            throw new BadGatewayException('Odoo onchange returned an unsupported domain payload.');
        }

        return domain;
    }

    private isPlainObject(value: unknown): value is Record<string, unknown> {
        return typeof value === 'object' && value !== null && !Array.isArray(value);
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

type OdooRelationValue = [number, string] | number | false | null | undefined;

interface OdooCurrentUserRecord {
    partner_id?: OdooRelationValue;
}

interface OdooFormattedFollower {
    id: number;
    partner_id?: OdooRelationValue;
    name?: string;
    display_name?: string;
    email?: string | false;
    is_active?: boolean;
}

interface OdooFormattedActivity {
    id: number;
    activity_type_id?: OdooRelationValue;
    summary?: string | false;
    note?: string | false;
    date_deadline: string;
    state?: string;
    can_write?: boolean;
    user_id?: OdooRelationValue;
}

interface OdooActivityTypeRecord {
    id: number;
    name: string;
    summary?: string | false;
    icon?: string | false;
    default_note?: string | false;
}

type OdooMenuActionReference = string | [string, number] | false | null | undefined;

interface OdooMenuRecord {
    id: number;
    name?: string;
    parent_id?: OdooMenuParentReference;
    action?: OdooMenuActionReference;
}

type OdooMenuParentReference = [number, string] | false | null | undefined;

interface OdooWindowActionRecord {
    id: number;
    name?: string;
    res_model?: string | false;
    view_mode?: string | false;
    target?: string | false;
}