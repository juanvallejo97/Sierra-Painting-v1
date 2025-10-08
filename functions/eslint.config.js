// Ensure ESLint loads the CJS flat config even in a project with "type": "commonjs".
// Re-export the CJS config so ESLint resolves this .js entry point.
module.exports = require('./eslint.config.cjs');
