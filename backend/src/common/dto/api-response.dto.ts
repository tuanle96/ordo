import type { ApiError, ApiResponseMeta } from '@ordo/shared';

export class ApiResponseDto<T> {
    constructor(
        public readonly success: boolean,
        public readonly data: T,
        public readonly errors: ApiError[] = [],
        public readonly meta?: ApiResponseMeta,
    ) { }
}