import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',

  fullyParallel: true,

  timeout: 30 * 1000,

  expect: {
    timeout: 5000,
  },

  use: {
    baseURL: 'http://localhost:5173',

    // hiện browser
    headless: false,

    viewport: {
      width: 1280,
      height: 720,
    },

    actionTimeout: 10000,

    ignoreHTTPSErrors: true,

    // debug cực hữu ích
    screenshot: 'only-on-failure',

    video: 'retain-on-failure',

    trace: 'on-first-retry',
  },

  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
      },
    },
  ],

  webServer: {
    command: 'npm run dev -- --host 127.0.0.1 --port 5173',

    url: 'http://localhost:5173',

    reuseExistingServer: !process.env.CI,

    timeout: 120 * 1000,
  },
});