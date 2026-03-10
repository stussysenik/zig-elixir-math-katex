import { expect, test } from "@playwright/test";

test("keeps the default screen blank except for the command bar", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByTestId("query-input")).toBeVisible();
  await expect(page.getByTestId("vision-upload-trigger")).toBeVisible();
  await expect(page.getByText(/drag & drop textbook photos/i)).toBeVisible();
  await expect(page.locator("#katex-output")).toHaveCount(0);
  await expect(page.locator("#desmos-surface")).toHaveCount(0);
  await expect(page.locator("#geogebra-surface")).toHaveCount(0);
});

test("runs the verified pipeline and switches graph tabs", async ({ page }) => {
  await page.setViewportSize({ width: 393, height: 852 });
  await page.goto("/");

  await page.getByTestId("query-input").fill("Graph the derivative of x^2");
  await page.getByTestId("submit-query").click();

  await expect
    .poll(async () => page.getByTestId("status-label").getAttribute("data-status"))
    .not.toBe("idle");

  await expect(page.locator("#katex-output .katex-display")).toBeVisible();
  await expect(page.getByTestId("proof-state")).toContainText("accepted");
  await expect(page.getByTestId("graph-tabs")).toBeVisible();
  await expect(page.getByTestId("desmos-surface")).toHaveAttribute("data-has-expressions", "true");
  await expect(page.locator("#geogebra-surface")).toHaveCount(0);

  await page.getByTestId("graph-tab-geogebra").click();
  await expect(page.getByTestId("geogebra-surface")).toBeVisible();
  await expect(page.locator("#desmos-surface")).toHaveCount(0);
});
