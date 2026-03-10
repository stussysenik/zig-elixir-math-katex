import { expect, test } from "@playwright/test";

test("runs the verified pipeline and updates the Desmos surface", async ({ page }) => {
  await page.goto("/");

  await page.getByTestId("query-input").fill("Graph the derivative of x^2");
  await page.getByTestId("submit-query").click();

  await expect
    .poll(async () => page.getByTestId("status-label").getAttribute("data-status"))
    .not.toBe("idle");

  await expect(page.locator("#katex-output .katex-display")).toBeVisible();
  await expect(page.getByTestId("proof-state")).toContainText("accepted");
  await expect(page.getByTestId("desmos-surface")).toHaveAttribute("data-has-expressions", "true");
});

test("toggles the Desmos layer without a full page reload", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByTestId("desmos-surface")).toBeVisible();
  await page.getByText("Engine", { exact: true }).click();
  await page.getByTestId("toggle-desmos").click();
  await expect(page.getByTestId("desmos-surface")).toHaveCount(0);
});
