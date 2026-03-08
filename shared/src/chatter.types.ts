export interface ChatterAuthor {
    id: number;
    name: string;
    type: 'partner' | 'guest';
}

export interface ChatterMessage {
    id: number;
    body: string;
    plainBody: string;
    date: string;
    messageType: string;
    isNote: boolean;
    isDiscussion: boolean;
    author?: ChatterAuthor;
}

export interface ChatterFollower {
    id: number;
    partnerId: number;
    name: string;
    email?: string;
    isActive: boolean;
    isSelf: boolean;
}

export interface ChatterActivityAssignee {
    id: number;
    name: string;
}

export interface ChatterActivityTypeOption {
    id: number;
    name: string;
    summary?: string;
    icon?: string;
    defaultNote?: string;
}

export interface ChatterActivity {
    id: number;
    typeId?: number;
    typeName: string;
    summary?: string;
    note: string;
    plainNote: string;
    dateDeadline: string;
    state: string;
    canWrite: boolean;
    assignedUser?: ChatterActivityAssignee;
}

export interface ChatterThreadResult {
    messages: ChatterMessage[];
    limit: number;
    hasMore: boolean;
    nextBefore?: number;
}

export interface ChatterDetailsResult {
    followers: ChatterFollower[];
    followersCount: number;
    selfFollower?: ChatterFollower;
    activities: ChatterActivity[];
    availableActivityTypes: ChatterActivityTypeOption[];
}

export interface PostChatterNoteRequest {
    body: string;
}

export interface CompleteChatterActivityRequest {
    feedback?: string;
}

export interface ScheduleChatterActivityRequest {
    activityTypeId: number;
    summary?: string;
    note?: string;
    dateDeadline?: string;
}