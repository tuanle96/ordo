import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

import tsParser from '@typescript-eslint/parser';

const rootDir = dirname(fileURLToPath(import.meta.url));

const restrictedRelativePatterns = [
    './*',
    '../*',
    '../../*',
    '../../../*',
    '../../../../*',
    '../../../../../*',
];

export default [
    {
        ignores: ['dist/**'],
    },
    {
        files: ['src/**/*.ts', 'test/**/*.ts'],
        languageOptions: {
            parser: tsParser,
            parserOptions: {
                project: './tsconfig.json',
                tsconfigRootDir: rootDir,
                sourceType: 'module',
            },
        },
        rules: {
            'no-restricted-imports': [
                'error',
                {
                    patterns: [
                        {
                            group: restrictedRelativePatterns,
                            message: 'Use @app/* or @test/* aliases instead of relative imports.',
                        },
                    ],
                },
            ],
        },
    },
];