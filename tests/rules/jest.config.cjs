module.exports = {
  testEnvironment: "node",
  setupFilesAfterEnv: ["<rootDir>/jest.setup.ts"],
  globalTeardown: "<rootDir>/jest.teardown.ts",
  testMatch: ["**/?(*.)+(spec|test).[tj]s"],
  // Keep reporters minimal in CI to reduce noise
  reporters: ["default"]
};
