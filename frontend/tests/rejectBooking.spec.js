import { test, expect } from '@playwright/test';

test('reject booking', async ({ page }) => {
    await page.goto('/');

    await page.getByTestId('home-signin-btn').click();
    await expect(page).toHaveURL(/login/);

    await page.getByTestId('email-login-input').fill('hluc3242@gmail.com');
    await page.getByTestId('password-login-input').fill('123456789');
    await page.getByTestId('login-button').click();
    await page.waitForLoadState('networkidle');
    await expect(page).not.toHaveURL(/login/);

    await page.goto('/rooms');

    const firstRoomCard = page.getByTestId('room-card').first();
    await expect(firstRoomCard).toBeVisible();

    const roomName = await firstRoomCard.getByTestId('room-name').textContent();
    const roomPriceText = await firstRoomCard.getByTestId('room-price').textContent();

    await firstRoomCard.getByTestId('book-room-button').click();
    await expect(page).toHaveURL(/booking-confirmation/);

    await page.getByTestId('booking-guests-select').click();
    await page.getByText('2 guests').click();
    await page.getByTestId('booking-checkin-input').fill('2026-05-30');
    await page.getByTestId('booking-checkout-input').fill('2026-06-02');

    await expect(page.getByText(roomName)).toBeVisible();
    await expect(page.getByTestId('booking-total-days')).toContainText('4 days');

    const roomPrice = Number(roomPriceText.replace(/[^0-9.]/g, ''));
    const expectedTotal = roomPrice * 4;
    await expect(page.getByTestId('booking-total-price')).toContainText(`$${expectedTotal}`);

    await page.getByTestId('confirm-booking-button').click();
    await expect(page.getByTestId('booking-success-title')).toBeVisible();
    await expect(page.getByText('Booking Confirmed!')).toBeVisible();

    await page.getByTestId('go-to-contract-button').click();
        await expect(page).toHaveURL('/contracts');

    await page.getByTestId('home-user-dropdown-btn').click();
    await page.getByRole('menuitem', { name: 'Sign Out' }).click();
    await expect(page).toHaveURL('/');

    await page.getByTestId('home-signin-btn').click();
    await expect(page).toHaveURL(/login/);

    await page.getByTestId('email-login-input').fill('trandoantriet@gmail.com');
    await page.getByTestId('password-login-input').fill('123456789');
    await page.getByTestId('login-button').click();
    await expect(page).toHaveURL(/admin\/dashboard/);

    await page.goto('/admin/booking-request');
    await page.waitForLoadState('networkidle');


    await page.getByTestId('reject-booking-button').first().click();

    await page.waitForTimeout(1000);

    const iframe = page.locator('iframe.tox-edit-area__iframe');

    await expect(iframe).toBeVisible();

    const editorFrame = page.frameLocator('iframe.tox-edit-area__iframe');

    await editorFrame.locator('body').click();

    await editorFrame.locator('body').fill(
    'Room is not available for the requested dates.'
    );

    await page.getByTestId('reject-booking-submit').click();
    
    await expect(page.getByText('The booking has been rejected successfully')).toBeVisible();
});