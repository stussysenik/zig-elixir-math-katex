const { defineConfig } = require("cypress")

module.exports = defineConfig({
  video: false,
  screenshotOnRunFailure: true,
  e2e: {
    baseUrl: "http://localhost:4012",
    specPattern: "cypress/e2e/**/*.cy.{js,jsx,ts,tsx}",
    supportFile: false,
  },
})
