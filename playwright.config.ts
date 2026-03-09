import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  timeout: 30_000,
  use: {
    baseURL: "http://localhost:4002",
    trace: "on-first-retry",
  },
  webServer: {
    command: "MIX_ENV=test mix assets.build && PHX_SERVER=true MIX_ENV=test mix phx.server",
    port: 4002,
    reuseExistingServer: true,
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
