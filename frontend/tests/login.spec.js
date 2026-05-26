import { test, expect } from '@playwright/test';

test.describe('Login Page', () => {
  test('admin login', async ({ page }) => {

    await page.goto('/');

    await page
      .getByTestId('home-signin-btn')
      .click();

    await expect(page).toHaveURL(/login/);

    await page
      .getByTestId('email-login-input')
      .fill('trandoantriet@gmail.com');

    await page
      .getByTestId('password-login-input')
      .fill('123456789');

    await page
      .getByTestId('login-button')
      .click();
    await expect(page).toHaveURL(/admin\/dashboard/);

    const cookies = await page.context().cookies();

    const accessToken = cookies.find(
      cookie => cookie.name === 'accessToken'
    );

    expect(accessToken).toBeTruthy();
  });
});