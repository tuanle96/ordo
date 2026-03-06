import { Injectable } from '@nestjs/common';

import type { Condition } from '@ordo/shared';

@Injectable()
export class ConditionParserService {
    parseInvisible(expression?: string): Condition | undefined {
        if (!expression) {
            return undefined;
        }

        const normalized = expression.trim();
        const listMatch = normalized.match(/^([a-zA-Z_][\w]*)\s+(in|not in)\s+\[(.+)\]$/);
        if (listMatch) {
            const [, field, op, rawValues] = listMatch;
            const values = rawValues
                .split(',')
                .map((value) => value.trim().replace(/^['"]|['"]$/g, ''))
                .filter(Boolean);

            return { field, op: op as 'in' | 'not in', values };
        }

        const scalarMatch = normalized.match(
            /^([a-zA-Z_][\w]*)\s*(==|!=|>=|<=|>|<)\s*(['"]?)(.+?)\3$/,
        );
        if (!scalarMatch) {
            return undefined;
        }

        const [, field, op, , value] = scalarMatch;
        return {
            field,
            op: op as Condition['op'],
            value,
        };
    }
}