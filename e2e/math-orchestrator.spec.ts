import { expect, test } from "@playwright/test";

test("submits a prompt and renders verified math", async ({ page }) => {
  await page.goto("/");

  await page.getByTestId("query-input").fill("derivative of sin(x)");
  await page.getByTestId("submit-query").click();

  await expect(page.getByTestId("status-label")).toContainText(/Computing|Verifying|Rendering/);
  await expect(page.locator("#katex-output .katex-display")).toBeVisible();
  await expect(page.getByTestId("proof-state")).toContainText("accepted");
});

test("toggles the Desmos layer without a full page reload", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByTestId("desmos-surface")).toBeVisible();
  await page.getByText("Engine", { exact: true }).click();
  await page.getByTestId("toggle-desmos").click();
  await expect(page.getByTestId("desmos-surface")).toHaveCount(0);
});
