import { Injectable } from '@nestjs/common';

import type { Condition, ConditionRule, ConditionValue } from '../../shared';

type TokenType =
    | 'identifier'
    | 'string'
    | 'number'
    | 'boolean'
    | 'null'
    | 'lparen'
    | 'rparen'
    | 'lbracket'
    | 'rbracket'
    | 'comma'
    | 'equals'
    | 'notEquals'
    | 'gt'
    | 'gte'
    | 'lt'
    | 'lte'
    | 'and'
    | 'or'
    | 'not'
    | 'in'
    | 'eof';

interface Token {
    type: TokenType;
    value?: string;
}

type PythonLiteral = ConditionValue | PythonLiteral[];

@Injectable()
export class ConditionParserService {
    parsePythonValue(expression?: string): unknown | undefined {
        if (!expression) {
            return undefined;
        }

        const normalized = expression.trim();
        if (!normalized) {
            return undefined;
        }

        try {
            const tokens = this.tokenize(normalized);
            const [value, index] = this.parsePythonLiteral(tokens, 0);
            if (value === undefined || tokens[index]?.type !== 'eof') {
                return undefined;
            }

            return value;
        } catch {
            return undefined;
        }
    }

    parseInvisible(expression?: string): Condition | undefined {
        return this.extractSingleCondition(this.parseRule(expression));
    }

    parseRule(expression?: string): ConditionRule | undefined {
        if (!expression) {
            return undefined;
        }

        const normalized = expression.trim();
        if (!normalized) {
            return undefined;
        }

        try {
            if (normalized.startsWith('[')) {
                return this.simplifyRule(this.parseDomainExpression(normalized));
            }

            const tokens = this.tokenize(normalized);
            const [rule, index] = this.parseOr(tokens, 0);
            if (!rule || tokens[index]?.type !== 'eof') {
                return undefined;
            }

            return this.simplifyRule(rule);
        } catch {
            return undefined;
        }
    }

    parseStates(states?: string): ConditionRule | undefined {
        if (!states) {
            return undefined;
        }

        const allowedStates = states
            .split(',')
            .map((value) => value.trim())
            .filter(Boolean);
        if (allowedStates.length === 0) {
            return undefined;
        }

        return {
            type: 'condition',
            condition: {
                field: 'state',
                op: 'not in',
                values: allowedStates,
            },
        };
    }

    private extractSingleCondition(rule?: ConditionRule): Condition | undefined {
        return rule?.type === 'condition' ? rule.condition : undefined;
    }

    private parseDomainExpression(expression: string): ConditionRule | undefined {
        const tokens = this.tokenize(expression);
        const [value, index] = this.parsePythonLiteral(tokens, 0);
        if (value === undefined || tokens[index]?.type !== 'eof') {
            return undefined;
        }

        return this.ruleFromDomainValue(value);
    }

    private ruleFromDomainValue(value: PythonLiteral): ConditionRule | undefined {
        if (typeof value === 'boolean') {
            return { type: 'constant', constant: value };
        }

        if (!Array.isArray(value)) {
            return undefined;
        }

        if (value.length === 0) {
            return { type: 'constant', constant: false };
        }

        const tupleCondition = this.conditionFromTuple(value);
        if (tupleCondition) {
            return { type: 'condition', condition: tupleCondition };
        }

        if (this.isDomainOperator(value[0])) {
            const [rule, nextIndex] = this.parseDomainSequence(value, 0);
            return nextIndex === value.length ? rule : undefined;
        }

        const rules = value
            .map((item) => this.ruleFromDomainValue(item))
            .filter((item): item is ConditionRule => Boolean(item));
        if (rules.length === 0) {
            return undefined;
        }

        return this.combine('and', rules);
    }

    private parseDomainSequence(items: PythonLiteral[], index: number): [ConditionRule | undefined, number] {
        const current = items[index];
        if (current === '&' || current === '|') {
            const [left, leftIndex] = this.parseDomainSequence(items, index + 1);
            const [right, rightIndex] = this.parseDomainSequence(items, leftIndex);
            if (!left || !right) {
                return [undefined, index];
            }

            return [this.combine(current === '&' ? 'and' : 'or', [left, right]), rightIndex];
        }

        if (current === '!') {
            const [child, nextIndex] = this.parseDomainSequence(items, index + 1);
            return child ? [this.simplifyRule({ type: 'not', rules: [child] }), nextIndex] : [undefined, index];
        }

        return [this.ruleFromDomainValue(current), index + 1];
    }

    private conditionFromTuple(value: PythonLiteral[]): Condition | undefined {
        if (value.length !== 3 || typeof value[0] !== 'string' || typeof value[1] !== 'string') {
            return undefined;
        }

        const op = this.normalizeOperator(value[1]);
        if (!op) {
            return undefined;
        }

        const field = value[0].trim();
        if (!field || field.includes('.') || field.includes('[')) {
            return undefined;
        }

        if (op === 'in' || op === 'not in') {
            if (!Array.isArray(value[2])) {
                return undefined;
            }

            const values = value[2].filter(this.isConditionValue);
            return { field, op, values };
        }

        if (!this.isConditionValue(value[2])) {
            return undefined;
        }

        return { field, op, value: value[2] };
    }

    private parseOr(tokens: Token[], index: number): [ConditionRule | undefined, number] {
        let [left, nextIndex] = this.parseAnd(tokens, index);
        if (!left) {
            return [undefined, index];
        }

        while (tokens[nextIndex]?.type === 'or') {
            const [right, rightIndex] = this.parseAnd(tokens, nextIndex + 1);
            if (!right) {
                return [undefined, index];
            }

            left = this.combine('or', [left, right]);
            nextIndex = rightIndex;
        }

        return [left, nextIndex];
    }

    private parseAnd(tokens: Token[], index: number): [ConditionRule | undefined, number] {
        let [left, nextIndex] = this.parseNot(tokens, index);
        if (!left) {
            return [undefined, index];
        }

        while (tokens[nextIndex]?.type === 'and') {
            const [right, rightIndex] = this.parseNot(tokens, nextIndex + 1);
            if (!right) {
                return [undefined, index];
            }

            left = this.combine('and', [left, right]);
            nextIndex = rightIndex;
        }

        return [left, nextIndex];
    }

    private parseNot(tokens: Token[], index: number): [ConditionRule | undefined, number] {
        if (tokens[index]?.type === 'not') {
            const [rule, nextIndex] = this.parseNot(tokens, index + 1);
            return rule ? [this.simplifyRule({ type: 'not', rules: [rule] }), nextIndex] : [undefined, index];
        }

        return this.parsePrimary(tokens, index);
    }

    private parsePrimary(tokens: Token[], index: number): [ConditionRule | undefined, number] {
        if (tokens[index]?.type === 'lparen') {
            const [rule, nextIndex] = this.parseOr(tokens, index + 1);
            if (!rule || tokens[nextIndex]?.type !== 'rparen') {
                return [undefined, index];
            }

            return [rule, nextIndex + 1];
        }

        if (tokens[index]?.type === 'boolean') {
            return [{ type: 'constant', constant: tokens[index].value === 'true' }, index + 1];
        }

        if (tokens[index]?.type === 'number') {
            const constant = this.numericConstant(tokens[index].value);
            return constant === undefined
                ? [undefined, index]
                : [{ type: 'constant', constant }, index + 1];
        }

        const comparison = this.parseComparison(tokens, index);
        if (comparison[0]) {
            return comparison;
        }

        const fieldToken = tokens[index];
        if (fieldToken?.type === 'identifier' && this.isBoundaryToken(tokens[index + 1]?.type)) {
            return [
                {
                    type: 'condition',
                    condition: {
                        field: fieldToken.value ?? '',
                        op: '==',
                        value: true,
                    },
                },
                index + 1,
            ];
        }

        return [undefined, index];
    }

    private parseComparison(tokens: Token[], index: number): [ConditionRule | undefined, number] {
        const fieldToken = tokens[index];
        if (fieldToken?.type !== 'identifier') {
            return [undefined, index];
        }

        const [op, opIndex] = this.parseComparisonOperator(tokens, index + 1);
        if (!op) {
            return [undefined, index];
        }

        const [value, nextIndex] = op === 'in' || op === 'not in'
            ? this.parseListValue(tokens, opIndex)
            : this.parseScalarValue(tokens, opIndex);
        if (value === undefined) {
            return [undefined, index];
        }

        return [
            {
                type: 'condition',
                condition: op === 'in' || op === 'not in'
                    ? { field: fieldToken.value ?? '', op, values: value as ConditionValue[] }
                    : { field: fieldToken.value ?? '', op, value: value as ConditionValue },
            },
            nextIndex,
        ];
    }

    private parseComparisonOperator(tokens: Token[], index: number): [Condition['op'] | undefined, number] {
        const token = tokens[index];
        switch (token?.type) {
            case 'equals':
                return ['==', index + 1];
            case 'notEquals':
                return ['!=', index + 1];
            case 'gt':
                return ['>', index + 1];
            case 'gte':
                return ['>=', index + 1];
            case 'lt':
                return ['<', index + 1];
            case 'lte':
                return ['<=', index + 1];
            case 'in':
                return ['in', index + 1];
            case 'not':
                return tokens[index + 1]?.type === 'in' ? ['not in', index + 2] : [undefined, index];
            default:
                return [undefined, index];
        }
    }

    private parseScalarValue(tokens: Token[], index: number): [ConditionValue | undefined, number] {
        const token = tokens[index];
        switch (token?.type) {
            case 'string':
                return [token.value ?? '', index + 1];
            case 'number':
                return [Number(token.value), index + 1];
            case 'boolean':
                return [token.value === 'true', index + 1];
            case 'null':
                return [null, index + 1];
            default:
                return [undefined, index];
        }
    }

    private parseListValue(tokens: Token[], index: number): [ConditionValue[] | undefined, number] {
        if (tokens[index]?.type !== 'lbracket') {
            return [undefined, index];
        }

        const values: ConditionValue[] = [];
        let nextIndex = index + 1;
        while (tokens[nextIndex] && tokens[nextIndex].type !== 'rbracket') {
            const [value, valueIndex] = this.parseScalarValue(tokens, nextIndex);
            if (value === undefined) {
                return [undefined, index];
            }

            values.push(value);
            nextIndex = valueIndex;

            if (tokens[nextIndex]?.type === 'comma') {
                nextIndex += 1;
            }
        }

        return tokens[nextIndex]?.type === 'rbracket' ? [values, nextIndex + 1] : [undefined, index];
    }

    private parsePythonLiteral(tokens: Token[], index: number): [PythonLiteral | undefined, number] {
        const token = tokens[index];
        switch (token?.type) {
            case 'string':
                return [token.value ?? '', index + 1];
            case 'number':
                return [Number(token.value), index + 1];
            case 'boolean':
                return [token.value === 'true', index + 1];
            case 'null':
                return [null, index + 1];
            case 'identifier':
                return [token.value ?? '', index + 1];
            case 'lbracket':
                return this.parsePythonSequence(tokens, index, 'lbracket', 'rbracket');
            case 'lparen':
                return this.parsePythonSequence(tokens, index, 'lparen', 'rparen');
            default:
                return [undefined, index];
        }
    }

    private parsePythonSequence(
        tokens: Token[],
        index: number,
        start: 'lparen' | 'lbracket',
        end: 'rparen' | 'rbracket',
    ): [PythonLiteral[] | undefined, number] {
        if (tokens[index]?.type !== start) {
            return [undefined, index];
        }

        const items: PythonLiteral[] = [];
        let nextIndex = index + 1;
        while (tokens[nextIndex] && tokens[nextIndex].type !== end) {
            const [item, itemIndex] = this.parsePythonLiteral(tokens, nextIndex);
            if (item === undefined) {
                return [undefined, index];
            }

            items.push(item);
            nextIndex = itemIndex;

            if (tokens[nextIndex]?.type === 'comma') {
                nextIndex += 1;
            }
        }

        return tokens[nextIndex]?.type === end ? [items, nextIndex + 1] : [undefined, index];
    }

    private tokenize(input: string): Token[] {
        const tokens: Token[] = [];
        let index = 0;

        while (index < input.length) {
            const current = input[index];
            if (!current) {
                break;
            }

            if (/\s/.test(current)) {
                index += 1;
                continue;
            }

            if (current === '(') {
                tokens.push({ type: 'lparen' });
                index += 1;
                continue;
            }

            if (current === ')') {
                tokens.push({ type: 'rparen' });
                index += 1;
                continue;
            }

            if (current === '[') {
                tokens.push({ type: 'lbracket' });
                index += 1;
                continue;
            }

            if (current === ']') {
                tokens.push({ type: 'rbracket' });
                index += 1;
                continue;
            }

            if (current === ',') {
                tokens.push({ type: 'comma' });
                index += 1;
                continue;
            }

            if (current === '=' && input[index + 1] === '=') {
                tokens.push({ type: 'equals' });
                index += 2;
                continue;
            }

            if ((current === '!' && input[index + 1] === '=') || (current === '<' && input[index + 1] === '>')) {
                tokens.push({ type: 'notEquals' });
                index += 2;
                continue;
            }

            if (current === '>' && input[index + 1] === '=') {
                tokens.push({ type: 'gte' });
                index += 2;
                continue;
            }

            if (current === '<' && input[index + 1] === '=') {
                tokens.push({ type: 'lte' });
                index += 2;
                continue;
            }

            if (current === '>') {
                tokens.push({ type: 'gt' });
                index += 1;
                continue;
            }

            if (current === '<') {
                tokens.push({ type: 'lt' });
                index += 1;
                continue;
            }

            if (current === '"' || current === '\'') {
                const quote = current;
                let value = '';
                index += 1;
                while (index < input.length && input[index] !== quote) {
                    value += input[index] ?? '';
                    index += 1;
                }
                index += 1;
                tokens.push({ type: 'string', value });
                continue;
            }

            const numberMatch = input.slice(index).match(/^-?\d+(?:\.\d+)?/);
            if (numberMatch) {
                tokens.push({ type: 'number', value: numberMatch[0] });
                index += numberMatch[0].length;
                continue;
            }

            const identifierMatch = input.slice(index).match(/^[A-Za-z_][\w.]*/);
            if (identifierMatch) {
                const raw = identifierMatch[0];
                const lowered = raw.toLowerCase();
                if (lowered === 'and' || lowered === 'or' || lowered === 'not' || lowered === 'in') {
                    tokens.push({ type: lowered as 'and' | 'or' | 'not' | 'in' });
                } else if (lowered === 'true' || lowered === 'false') {
                    tokens.push({ type: 'boolean', value: lowered });
                } else if (lowered === 'none' || lowered === 'null') {
                    tokens.push({ type: 'null' });
                } else {
                    tokens.push({ type: 'identifier', value: raw });
                }
                index += raw.length;
                continue;
            }

            throw new Error(`Unsupported token at index ${index}`);
        }

        tokens.push({ type: 'eof' });
        return tokens;
    }

    private normalizeOperator(operator: string): Condition['op'] | undefined {
        switch (operator) {
            case '=':
            case '==':
                return '==';
            case '!=':
            case '<>':
                return '!=';
            case '>':
            case '<':
            case '>=':
            case '<=':
            case 'in':
            case 'not in':
                return operator;
            default:
                return undefined;
        }
    }

    private numericConstant(rawValue?: string): boolean | undefined {
        switch (rawValue) {
            case '1':
                return true;
            case '0':
                return false;
            default:
                return undefined;
        }
    }

    private isBoundaryToken(tokenType?: TokenType): boolean {
        return tokenType === 'eof'
            || tokenType === 'rparen'
            || tokenType === 'and'
            || tokenType === 'or'
            || tokenType === 'comma'
            || tokenType === 'rbracket';
    }

    private combine(type: 'and' | 'or', rules: ConditionRule[]): ConditionRule {
        return this.simplifyRule({ type, rules }) ?? { type, rules };
    }

    private simplifyRule(rule?: ConditionRule): ConditionRule | undefined {
        if (!rule) {
            return undefined;
        }

        if (rule.type === 'not') {
            const child = this.simplifyRule(rule.rules?.[0]);
            if (!child) {
                return undefined;
            }

            if (child.type === 'constant') {
                return { type: 'constant', constant: !child.constant };
            }

            return { type: 'not', rules: [child] };
        }

        if (rule.type === 'and' || rule.type === 'or') {
            const flattened = (rule.rules ?? [])
                .map((item: ConditionRule) => this.simplifyRule(item))
                .filter((item: ConditionRule | undefined): item is ConditionRule => Boolean(item))
                .flatMap((item: ConditionRule) => item.type === rule.type ? item.rules ?? [] : [item]);

            if (rule.type === 'and' && flattened.some((item: ConditionRule) => item.type === 'constant' && item.constant === false)) {
                return { type: 'constant', constant: false };
            }

            if (rule.type === 'or' && flattened.some((item: ConditionRule) => item.type === 'constant' && item.constant === true)) {
                return { type: 'constant', constant: true };
            }

            const filtered = flattened.filter((item: ConditionRule) => item.type !== 'constant');
            if (filtered.length === 0) {
                return { type: 'constant', constant: rule.type === 'and' };
            }

            if (filtered.length === 1) {
                return filtered[0];
            }

            return { type: rule.type, rules: filtered };
        }

        return rule;
    }

    private isConditionValue(value: PythonLiteral): value is ConditionValue {
        return value === null || ['string', 'number', 'boolean'].includes(typeof value);
    }

    private isDomainOperator(value: PythonLiteral | undefined): value is '&' | '|' | '!' {
        return value === '&' || value === '|' || value === '!';
    }
}