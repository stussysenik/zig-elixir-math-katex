describe("MathViz smoke", () => {
  it("keeps the default screen blank except for the command bar", () => {
    cy.visit("/")

    cy.get("[data-testid='query-input']").should("be.visible")
    cy.get("[data-testid='vision-upload-trigger']").should("be.visible")
    cy.contains(/drag & drop textbook photos/i).should("be.visible")
    cy.get("#katex-output").should("not.exist")
    cy.get("#desmos-surface").should("not.exist")
    cy.get("#geogebra-surface").should("not.exist")
  })

  it("runs the verified pipeline and switches graph tabs", () => {
    cy.visit("/")

    cy.get("[data-testid='query-input']").type("Graph the derivative of x^2")
    cy.get("[data-testid='submit-query']").click()

    cy.get("#katex-output .katex-display").should("exist")
    cy.get("[data-testid='proof-state']").should("contain.text", "accepted")
    cy.get("[data-testid='graph-tabs']").should("be.visible")
    cy.get("#desmos-surface").should("have.attr", "data-has-expressions", "true")
    cy.get("#geogebra-surface").should("not.exist")

    cy.get("[data-testid='graph-tab-geogebra']").click()
    cy.get("#geogebra-surface").should("be.visible")
    cy.get("#desmos-surface").should("not.exist")
  })

  it("routes theory prompts to chat output without graph rendering", () => {
    cy.visit("/")

    cy.get("[data-testid='query-input']").type("What is an integral?")
    cy.get("[data-testid='submit-query']").click()

    cy.get("[data-testid='chat-output']").should("be.visible")
    cy.get("[data-testid='chat-output']").should("contain.text", "integral")
    cy.get("#katex-output").should("not.exist")
    cy.get("#desmos-surface").should("not.exist")
    cy.get("#geogebra-surface").should("not.exist")
    cy.get("[data-testid='graph-tabs']").should("not.exist")
  })

  it("keeps Enter for newlines and submits on Ctrl+Enter", () => {
    cy.visit("/")

    cy.get("[data-testid='query-input']")
      .type("What is an integral?")
      .type("{enter}")
      .should("have.value", "What is an integral?\n")

    cy.get("[data-testid='chat-output']").should("not.exist")

    cy.get("[data-testid='query-input']").type("{ctrl}{enter}")
    cy.get("[data-testid='chat-output']").should("be.visible")
    cy.get("[data-testid='chat-output']").should("contain.text", "integral")
  })
})
