/* eslint-env node */
module.exports = {
  root: true,
  env: { node: true, es2022: true },
  ignorePatterns: ['.eslintrc.js', 'lib/**', 'node_modules/**'],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    tsconfigRootDir: __dirname,
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
  overrides: [
    {
      files: ['*.js'],
      // Use the default JS parser for plain JS files
      parser: 'espree',
      parserOptions: { ecmaVersion: 2022 }
    }
  ],
  rules: {
    'import/no-unresolved': 'off'
  }
};
