// Minimal flat-config for ESLint v9 + TypeScript ESLint v8
import js from '@eslint/js';

export default [
  // Baseline JS rules
  js.configs.recommended,

  // Project-wide settings and ignores
  {
    ignores: [
      'node_modules/**',
      'lib/**',
      'dist/**',
      'coverage/**',
      '.firebase/**',
    ],
    languageOptions: await (async () => {
      const parserModule = await import('@typescript-eslint/parser');

      return {
        // Use the TS parser in a non-type-checking mode to avoid parser project path issues
        parser: { parseForESLint: parserModule.parseForESLint },
        parserOptions: {
          ecmaVersion: 2022,
          sourceType: 'module',
        },
        globals: {
          describe: 'readonly',
          it: 'readonly',
          test: 'readonly',
          expect: 'readonly',
          beforeAll: 'readonly',
          beforeEach: 'readonly',
          afterAll: 'readonly',
          afterEach: 'readonly',
          jest: 'readonly',
          // Node & runtime globals
          Buffer: 'readonly',
          process: 'readonly',
          console: 'readonly',
          require: 'readonly',
          AbortController: 'readonly',
          setTimeout: 'readonly',
          clearTimeout: 'readonly',
        },
      };
    })(),
    plugins: await (async () => {
      const pluginModule = await import('@typescript-eslint/eslint-plugin');
      const importPluginModule = await import('eslint-plugin-import');
      const plugin = pluginModule.default ?? pluginModule;
      const importPlugin = importPluginModule.default ?? importPluginModule;
      return { '@typescript-eslint': plugin, import: importPlugin };
    })(),
  },

  // Project rules & overrides
  {
    files: ['src/**/*.ts', 'test/**/*.ts', 'scripts/**/*.ts'],
    rules: {
      'no-unused-vars': 'off',
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
      '@typescript-eslint/consistent-type-imports': 'off',
      // Allow devDeps in functions (tests & scripts) if needed; keep as warn or error per policy
      'import/no-extraneous-dependencies': ['error', { devDependencies: ['test/**', 'src/**/test/**', 'src/test/**', 'src/**/__tests__/**', 'test/**', 'scripts/**'] }],
    },
  },
  // Tests: relax unused-var rules in test files to avoid many intentional unused args
  {
    files: ['test/**/*.ts', 'src/**/__tests__/**/*.ts', 'src/**/*.{spec,test}.ts'],
    rules: {
      '@typescript-eslint/no-unused-vars': 'off',
      '@typescript-eslint/consistent-type-imports': 'off'
    }
  },
  {
    files: ['test/**/*.ts', 'src/**/__tests__/**/*.ts', 'src/**/*.{spec,test}.ts'],
    rules: {
      '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
    },
  },
];
