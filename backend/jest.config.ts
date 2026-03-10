import type { Config } from 'jest';

const config: Config = {
    rootDir: '.',
    moduleFileExtensions: ['js', 'json', 'ts'],
    testEnvironment: 'node',
    testRegex: '.*\\.spec\\.ts$',
    transform: {
        '^.+\\.(t|j)s$': ['ts-jest', { tsconfig: '<rootDir>/tsconfig.json' }],
    },
    moduleNameMapper: {
        '^@app/(.*)$': '<rootDir>/src/$1',
        '^@test/(.*)$': '<rootDir>/test/$1',
    },
    roots: ['<rootDir>/src', '<rootDir>/test'],
    collectCoverageFrom: ['src/**/*.ts', '!src/main.ts'],
    clearMocks: true,
};

export default config;