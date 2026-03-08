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

export interface ChatterThreadResult {
    messages: ChatterMessage[];
    limit: number;
    hasMore: boolean;
    nextBefore?: number;
}

export interface PostChatterNoteRequest {
    body: string;
}