import { test, expect } from '@playwright/test';

test.describe('Login Page', () => {
  test('user login', async ({ page }) => {

    await page.goto('/');

    await page
      .getByTestId('home-signin-btn')
      .click();

    await expect(page).toHaveURL(/login/);

    await page
      .getByTestId('email-login-input')
      .fill('hluc3242@gmail.com');

    await page
      .getByTestId('password-login-input')
      .fill('12345678');

    await page
      .getByTestId('login-button')
      .click();
    await expect(page).toHaveURL(/\//);

  });
});