import katex from "katex"

export const MathRender = {
  mounted() {
    this.renderMath()
  },

  updated() {
    this.renderMath()
  },

  renderMath() {
    const rawLatex = this.el.dataset.latex || ""

    if (!rawLatex) {
      this.el.innerHTML = "<p class=\"text-sm text-stone-500\">Verified math will render here.</p>"
      return
    }

    katex.render(rawLatex, this.el, {
      throwOnError: false,
      displayMode: true,
      strict: false,
    })
  },
}
