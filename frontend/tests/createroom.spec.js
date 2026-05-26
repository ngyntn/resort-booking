import { test, expect } from '@playwright/test';

test('create room successfully', async ({ page }) => {
  await page.goto('/');

  await page.getByTestId('home-signin-btn').click();

  await expect(page).toHaveURL(/login/);

  await page.getByTestId('email-login-input')
    .fill('trandoantriet@gmail.com');

  await page.getByTestId('password-login-input')
    .fill('123456789');

  await page.getByTestId('login-button').click();

  await expect(page).toHaveURL(/admin\/dashboard/);

  await page.goto('/admin/room-management');

  await page.getByTestId('create-room-button').click();

  // ROOM NUMBER
  const randomRoomNumber = `DR-${Date.now()}`;
  await page.getByTestId('creating-room-number-input')
    .fill(randomRoomNumber);

  // MAX PEOPLE
  await page.getByTestId('creating-room-max-people-input')
    .fill('2');

  // ROOM TYPE
  await page.getByTestId('creating-room-type-select')
    .click();

  await page
    .locator('.ant-select-item-option-content')
    .filter({ hasText: 'Deluxe Room' })
    .click();

  // PRICE
  await page.getByTestId('creating-room-price-input')
    .fill('70');

  // TINYMCE
  await expect(page.locator('iframe')).toBeVisible();

  const editorFrame = page.frameLocator('iframe');

  await editorFrame
    .locator('body')
    .fill('room test description');

  // UPLOAD IMAGE
  await page
    .locator('[data-testid="creating-room-media-upload"] input[type="file"]')
    .setInputFiles('tests/assets/anh-test.jpg');

  // WAIT UPLOAD DONE
  await expect(
    page.locator('.ant-upload-list-item-done')
  ).toBeVisible();

  // SUBMIT
  await page.getByRole('button', { name: 'Submit' })
    .click();

  // SUCCESS
  await expect(
    page.getByText('Room created successfully!')
  ).toBeVisible();

  await page.goto('/admin/room-management');

  await expect(
        page.getByText(randomRoomNumber)
    ).toBeVisible();
});