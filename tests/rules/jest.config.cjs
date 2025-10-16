module.exports = {
  testEnvironment: "node",
  testMatch: ["**/*.test.js"],
  testTimeout: 30000,
  // Keep reporters minimal in CI to reduce noise
  reporters: ["default"]
};
