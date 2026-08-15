module.exports = {
  preset: "@react-native/jest-preset",
  setupFiles: ["<rootDir>/jest.setup.js"],
  transformIgnorePatterns: [
    "node_modules/(?!(@react-native|react-native|@react-navigation|react-native-track-player|react-native-blob-util|@react-native-async-storage)/)",
  ],
};
