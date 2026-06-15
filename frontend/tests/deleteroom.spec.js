import { test, expect } from '@playwright/test';

test('delete room ', async ({ page }) => {
  await page.goto('/');

  await page.getByTestId('home-signin-btn').click();

  await expect(page).toHaveURL(/login/);

  await page.getByTestId('email-login-input').fill('trandoantriet@gmail.com');
  await page.getByTestId('password-login-input').fill('123456789');
  await page.getByTestId('login-button').click();

  await expect(page).toHaveURL(/admin\/dashboard/);

  await page.goto('/admin/room-management');

  await page.getByTestId('create-room-button').click();

  const randomRoomNumber = `DR-${Date.now()}`;
  await page.getByTestId('creating-room-number-input').fill(randomRoomNumber);
  await page.getByTestId('creating-room-max-people-input').fill('2');

  await page.getByTestId('creating-room-type-select').click();
  await page
    .locator('.ant-select-item-option-content')
    .filter({ hasText: 'Deluxe Room' })
    .click();

  await page.getByTestId('creating-room-price-input').fill('70');

  await expect(page.locator('iframe')).toBeVisible();
  const editorFrame = page.frameLocator('iframe');
  await editorFrame.locator('body').fill('room test description');

  await page
    .locator('[data-testid="creating-room-media-upload"] input[type="file"]')
    .setInputFiles('tests/assets/anh-test.jpg');

  await expect(page.locator('.ant-upload-list-item-done')).toBeVisible();

  await page.getByRole('button', { name: 'Submit' }).click();

  await expect(page.getByText('Room created successfully!')).toBeVisible();

  const roomRow = page.locator('tbody tr').filter({ hasText: randomRoomNumber });
  await expect(roomRow).toBeVisible();

  await roomRow.locator('[data-testid^="delete-room-button-"]').click();

  await expect(page.getByText('Room deleted successfully!')).toBeVisible();
  await expect(page.locator('tbody tr').filter({ hasText: randomRoomNumber })).toHaveCount(0);
});
