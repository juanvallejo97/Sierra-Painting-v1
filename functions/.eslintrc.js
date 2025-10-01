/* eslint-env node */
module.exports = {
  root: true,
  env: { node: true, es2022: true },

  // Don’t lint the config file itself or build output
  ignorePatterns: ['.eslintrc.js', 'lib/**', 'node_modules/**'],

  parser: '@typescript-eslint/parser',
  parserOptions: {
    tsconfigRootDir: __dirname,
    // Use a TSConfig that ONLY includes TypeScript source files
    project: ['./tsconfig.eslint.json'],
    sourceType: 'module'
  },

  plugins: ['@typescript-eslint', 'import'],
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:@typescript-eslint/recommended-requiring-type-checking',
    'plugin:import/recommended',
    'plugin:import/typescript',
    'prettier'
  ],

  // If you have any plain JS files, use the JS parser for them
  overrides: [
    {
      files: ['*.js'],
      parser: 'espree',
      parserOptions: { ecmaVersion: 2022 }
    }
  ],

  // Light defaults; keep noisy rules off unless you want stricter gates
  rules: {
    'import/no-unresolved': 'off'
  },

  // Helps eslint-plugin-import resolve TS paths (optional but nice)
  settings: {
    'import/resolver': {
      typescript: {
        project: ['./tsconfig.eslint.json'],
         alwaysTryTypes: true
      }
    }
  },
};
