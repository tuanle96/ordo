export interface ApiError {
    code: string;
    message: string;
    field?: string;
}

export interface ApiResponseMeta {
    total?: number;
    offset?: number;
    limit?: number;
    timestamp?: string;
}

export interface ApiResponse<T> {
    success: boolean;
    data: T;
    meta?: ApiResponseMeta;
    errors: ApiError[];
}